local M = {}

local function read(path)
    if not path or path == "" then return nil end
    return noctalia.readFile(path)
end

function M.config()
    local raw = read(noctalia.getConfig("config_file"))
    local cfg = raw and noctalia.json.decode(raw)
    if type(cfg) ~= "table" then return nil, "Invalid widget config" end
    local domain = read(cfg.domain_file)
    local url = cfg.url or (domain and cfg.url_prefix and (cfg.url_prefix .. noctalia.string.trim(domain)))
    if not url then return nil, "Grafana URL unavailable" end
    local token = read(cfg.token_file)
    if not token then return nil, "Grafana token unavailable" end
    cfg.url = string.gsub(url, "/+$", "")
    cfg.token = noctalia.string.trim(token)
    return cfg
end

function M.request(cfg, path, body, done)
    local request = {
        url = cfg.url .. path,
        method = body and "POST" or "GET",
        headers = { "Authorization: Bearer " .. cfg.token, "Accept: application/json" },
    }
    if body then
        request.headers[#request.headers + 1] = "Content-Type: application/json"
        request.body = noctalia.json.encode(body)
    end
    local ok = noctalia.http(request, function(response)
        if not response.ok or response.status ~= 200 then
            done(nil, "Grafana HTTP " .. tostring(response.status))
            return
        end
        local data = noctalia.json.decode(response.body)
        if not data then done(nil, "Invalid Grafana response") else done(data) end
    end)
    if not ok then done(nil, "Could not start Grafana request") end
end

function M.dashboard(cfg, uid, done)
    M.request(cfg, "/api/dashboards/uid/" .. noctalia.string.urlEncode(uid), nil, function(data, err)
        if err then done(nil, err) else done(data.dashboard) end
    end)
end

function M.panel(dashboard, id)
    for _, panel in ipairs(dashboard.panels or {}) do
        if panel.id == id then return panel end
    end
    return nil
end

local function replaceLiteral(text, needle, replacement)
    local out = {}
    local start = 1
    while true do
        local first, last = string.find(text, needle, start, true)
        if not first then
            out[#out + 1] = string.sub(text, start)
            return table.concat(out)
        end
        out[#out + 1] = string.sub(text, start, first - 1)
        out[#out + 1] = replacement
        start = last + 1
    end
end

function M.query(cfg, panels, periodMs, replacements, done)
    local queries = {}
    local intervalMs = math.max(1000, math.floor(periodMs / 120))
    for i, panel in ipairs(panels) do
        local target = panel and panel.targets and panel.targets[1]
        if not target then done(nil, "Panel has no query") return end
        -- These are Grafana's own panel queries, not SQL supplied by the widget.
        local query = {}
        for key, value in pairs(target) do query[key] = value end
        for needle, value in pairs(replacements or {}) do
            if query.rawSql then query.rawSql = replaceLiteral(query.rawSql, needle, value) end
        end
        query.refId = string.char(64 + i)
        query.intervalMs = intervalMs
        query.maxDataPoints = 120
        queries[#queries + 1] = query
    end
    local now = os.time() * 1000
    M.request(cfg, "/api/ds/query", {
        from = tostring(now - periodMs), to = tostring(now), queries = queries,
    }, function(data, err)
        if err then done(nil, err) else done(data.results or {}) end
    end)
end

function M.points(results, ref, fieldName, fillMissing)
    local result = results[ref] or {}
    if result.error then return {}, result.error end
    local points = {}
    for _, frame in ipairs(result.frames or {}) do
        local fields = (frame.schema or {}).fields or {}
        local values = (frame.data or {}).values or {}
        local ti, vi
        for i, field in ipairs(fields) do
            if field.type == "time" then ti = i
            elseif field.type == "number" and (not fieldName and not vi or fieldName == field.name) then vi = i end
        end
        if not vi then
            for i, field in ipairs(fields) do
                if field.type == "number" and (not fieldName or fieldName == field.name) then vi = i; break end
            end
        end
        local column = vi and (values[vi] or {}) or {}
        if vi and ti then
            local initial
            if fillMissing then
                for i = 1, #(values[ti] or {}) do
                    local entry = column[i]
                    initial = type(entry) == "number" and entry or (type(entry) == "string" and tonumber(entry) or nil)
                    if initial then break end
                end
            end
            for i, stamp in ipairs(values[ti] or {}) do
                local entry = column[i]
                local n = type(entry) == "number" and entry or (type(entry) == "string" and tonumber(entry) or nil)
                if n or (fillMissing and initial) then
                    points[#points + 1] = { time = tonumber(stamp), value = n or (points[#points] and points[#points].value or initial) }
                end
            end
        elseif vi then
            for _, entry in ipairs(column) do
                local n = type(entry) == "number" and entry or (type(entry) == "string" and tonumber(entry) or nil)
                if n then points[#points + 1] = { time = os.time() * 1000, value = n } end
            end
        end
    end
    table.sort(points, function(a, b) return a.time < b.time end)
    return points
end

function M.thresholdColor(panel, number)
    local defaults = (((panel or {}).fieldConfig or {}).defaults or {})
    local steps = ((defaults.thresholds or {}).steps or {})
    local name = "blue"
    for _, step in ipairs(steps) do
        if step.value == nil or number >= step.value then name = step.color end
    end
    local colors = {
        green = "#a3be8c", yellow = "#ebcb8b", orange = "#d08770",
        red = "#bf616a", ["dark-red"] = "#bf616a", blue = "#88c0d0",
    }
    return colors[name] or name
end

return M
