local api = require("./api.luau")

return function(key)
    local M = {}
    local cfg, configError = api.config()
    local tile = cfg and (cfg.charts or {})[key]
    local dashboard
    local series = {}
    local errorText = configError
    local busy = false
    local periodIndex = 1
    local fetchedAt = 0
    local lastBoxWidth, lastBoxHeight
    local refresh

    local function period()
        return (cfg and cfg.periods or {})[periodIndex] or { label = "1h", ms = 3600000 }
    end

    local function bounds()
        local low, high
        for _, points in ipairs(series) do
            for _, point in ipairs(points) do
                low = low and math.min(low, point.value) or point.value
                high = high and math.max(high, point.value) or point.value
            end
        end
        if low and tile.axis_from_zero then low = math.min(0, low) end
        return low, high
    end

    local function scaled(points, low, high, firstTime, lastTime)
        if not points or #points == 0 then return {} end
        local out = {}
        local cursor = 1
        local function normalize(value)
            return high == low and 0.5 or (value - low) / (high - low)
        end
        for i = 0, 119 do
            local t = firstTime + (lastTime - firstTime) * i / 119
            while cursor < #points - 1 and points[cursor + 1].time < t do
                cursor = cursor + 1
            end
            local a = points[cursor]
            local b = points[math.min(cursor + 1, #points)]
            local fraction = b.time > a.time and math.clamp((t - a.time) / (b.time - a.time), 0, 1) or 0
            local value = a.value + (b.value - a.value) * fraction
            if i == 0 then
                -- ui.graph starts drawing at index 2, not index 0.
                out[1] = normalize(value)
                out[2] = out[1]
            end
            out[#out + 1] = normalize(value)
        end
        return out
    end

    local function render()
        local low, high = bounds()
        local lines = tile and tile.series or {}
        local colors = { "#88c0d0", "#a3be8c" }
        local unit = tile and tile.unit or ""
        local axisFormat = "%." .. tostring(tile and tile.axis_decimals or 0) .. "f"
        local layoutWidth, graphHeight = 336, 120
        -- HTTP callbacks have no widget snapshot; use the last size from update().
        local boxWidth, boxHeight = lastBoxWidth or 0, lastBoxHeight or 0
        if boxWidth > 0 and boxHeight > 0 then
            local aspect = math.clamp(boxWidth / boxHeight, 0.5, 8)
            -- Match the content aspect to the resized tile instead of letterboxing it.
            layoutWidth = math.max(336, math.floor(aspect * 190 - 24))
            graphHeight = math.max(120, math.floor((layoutWidth + 24) / aspect - 70))
        end
        local plotWidth = layoutWidth - 36
        local first, last
        for _, points in ipairs(series) do
            if #points > 0 then
                first = math.min(first or points[1].time, points[1].time)
                last = math.max(last or points[#points].time, points[#points].time)
            end
        end
        local titleVisible = not tile or (tile.title_visible ~= false and tile.title ~= "")
        local function periodButton()
            return ui.row({ onClick = "cyclePeriod", align = "center" }, {
                ui.label({ text = period().label .. " ›", fontSize = tile and tile.period_font_size or 19, color = "primary" }),
            })
        end
        local children = {}
        if titleVisible then
            local title = tile and tile.title or key
            local titleSize = tile and tile.title_font_size or 18
            local titleParts = {}
            if tile and tile.icon then
                titleParts[#titleParts + 1] = ui.glyph({ name = tile.icon, size = titleSize, color = "on_surface" })
            end
            titleParts[#titleParts + 1] = ui.label({ text = title,
                fontSize = titleSize, fontWeight = "bold", color = "on_surface" })
            local header = {}
            if tile and tile.title_align == "center" then
                -- An empty spacer balances the period button without drawing or intercepting clicks.
                header[#header + 1] = ui.row({ width = 60, height = 1 }, {})
            end
            header[#header + 1] = ui.row({ gap = 6, align = "center" }, titleParts)
            header[#header + 1] = periodButton()
            children[#children + 1] = ui.row({ align = "center", justify = "space_between", minWidth = layoutWidth, gap = 8 }, header)
        end
        local axisSize = tile and tile.axis_font_size or 13
        local axis = ui.column({ width = 32, justify = "space_between", minHeight = graphHeight, paddingV = 7 }, {
            ui.label({ text = high and string.format(axisFormat, high) or "—", width = 32, textAlign = "end", fontSize = axisSize }),
            ui.label({ text = low and string.format(axisFormat, low) or "—", width = 32, textAlign = "end", fontSize = axisSize }),
        })
        children[#children + 1] = ui.row({ gap = 4, align = "center" }, {
            axis,
            ui.graph({ values = low and scaled(series[1], low, high, first, last) or {},
                values2 = low and scaled(series[2], low, high, first, last) or {},
                color = colors[1], color2 = colors[2], width = plotWidth, height = graphHeight, lineWidth = 2 }),
        })
        local legend = {}
        for i, line in ipairs(lines) do
            local points = series[i] or {}
            local latest = points[#points]
            legend[#legend + 1] = ui.label({
                text = line.alias .. "  " .. (latest and string.format("%.1f", latest.value) .. unit or "—"),
                fontSize = tile and tile.legend_font_size or 14, color = colors[i] or "primary",
            })
        end
        if not titleVisible then legend[#legend + 1] = periodButton() end
        children[#children + 1] = ui.row({ justify = "space_between", minWidth = layoutWidth, align = "center" }, legend)
        if errorText then children[#children + 1] = ui.label({ text = errorText, fontSize = 12 }) end
        desktopWidget.render(ui.column({ gap = 5, padding = 12 }, children))
    end

    refresh = function()
        if not cfg or busy then return end
        if not tile then errorText = "Unknown Grafana chart"; render(); return end
        busy = true
        local requestedPeriod = periodIndex
        local function query()
            local panel = api.panel(dashboard, tile.panel_id)
            if not panel then busy = false; errorText = "Missing Grafana panel"; render(); return end
            api.query(cfg, { panel }, period().ms, tile.replacements, function(results, err)
                busy = false
                if requestedPeriod ~= periodIndex then refresh(); return end
                errorText = err
                if results then
                    for i, line in ipairs(tile.series or {}) do
                        local points, queryError = api.points(results, "A", line.field, true)
                        if queryError then errorText = queryError end
                        series[i] = points
                    end
                    if not errorText then fetchedAt = os.time() end
                end
                render()
            end)
        end
        if dashboard then query() else
            api.dashboard(cfg, tile.dashboard_uid, function(data, err)
                if err then busy = false; errorText = err; render(); return end
                dashboard = data
                query()
            end)
        end
    end

    function M.cyclePeriod()
        if not cfg or #(cfg.periods or {}) == 0 then return end
        periodIndex = periodIndex % #cfg.periods + 1
        series = {}
        render()
        if not busy then refresh() end
    end

    function M.update()
        if not cfg then
            cfg, configError = api.config()
            tile = cfg and (cfg.charts or {})[key]
            errorText = configError
        end
        noctalia.setUpdateInterval(cfg and 60000 or 5000)
        local boxWidth, boxHeight = desktopWidget.boxSize()
        local resized = boxWidth ~= lastBoxWidth or boxHeight ~= lastBoxHeight
        lastBoxWidth, lastBoxHeight = boxWidth, boxHeight
        if not busy and (not resized or fetchedAt == 0) then refresh() end
        if fetchedAt > 0 and os.time() - fetchedAt > 180 then errorText = "Grafana unavailable" end
        render()
    end

    return M
end
