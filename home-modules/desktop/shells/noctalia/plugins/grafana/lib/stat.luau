local api = require("./api.luau")

return function(key)
    local M = {}
    local cfg, configError = api.config()
    local tile = cfg and (cfg.values or {})[key]
    local dashboard
    local reading
    local errorText = configError
    local busy = false
    local fetchedAt = 0

    local function render()
        local stale = reading and (os.time() * 1000 - reading.time > 15 * 60 * 1000)
        local color = reading and not stale and api.thresholdColor(reading.panel, reading.value) or "on_surface_variant"
        local value = reading and string.format(tile.format or "%.1f", reading.value) or "—"
        local children = {}
        if not tile or (tile.title_visible ~= false and tile.title ~= "") then
            local centered = tile and tile.title_align == "center"
            local titleSize = tile and tile.title_font_size or 17
            local titleParts = {}
            if tile and tile.icon then
                titleParts[#titleParts + 1] = ui.glyph({ name = tile.icon, size = titleSize, color = "on_surface" })
            end
            titleParts[#titleParts + 1] = ui.label({ text = tile and tile.title or key,
                fontSize = titleSize, fontWeight = "bold", color = "on_surface" })
            local header = { ui.row({ gap = 6, align = "center" }, titleParts) }
            if tile and tile.unit then
                header[#header + 1] = ui.label({ text = tile.unit,
                    fontSize = tile.unit_font_size or 16, color = "on_surface_variant" })
            end
            children[#children + 1] = ui.row({ width = 162, align = "center", gap = 6,
                justify = centered and "center" or "space_between" }, header)
            children[#children + 1] = ui.separator({ orientation = "horizontal", width = 162,
                thickness = 1, color = "on_surface_variant", spacing = 2 })
        end
        children[#children + 1] = ui.label({ text = value, width = 162, textAlign = "center",
            fontSize = tile and tile.value_font_size or 48, fontWeight = "bold", color = color })
        if errorText or stale then
            children[#children + 1] = ui.label({ text = errorText or "Stale reading", fontSize = 12,
                color = "on_surface_variant" })
        end
        desktopWidget.render(ui.column({ gap = 4, padding = 14, align = "center" }, children))
    end

    local function refresh()
        if not cfg or busy then return end
        if not tile then errorText = "Unknown Grafana value tile"; render(); return end
        busy = true
        local function query()
            local panel = api.panel(dashboard, tile.panel_id)
            if not panel then busy = false; errorText = "Missing Grafana panel"; render(); return end
            local rangeMs = 24 * 3600 * 1000
            if tile.range == "today" then
                local now = os.time()
                local date = os.date("*t", now)
                local midnight = os.time({ year = date.year, month = date.month, day = date.day, hour = 0 })
                rangeMs = math.max(1000, (now - midnight) * 1000)
            end
            api.query(cfg, { panel }, rangeMs, tile.replacements, function(results, err)
                busy = false
                errorText = err
                if results then
                    local points, queryError = api.points(results, "A")
                    if queryError then errorText = queryError end
                    local last = points[#points]
                    reading = last and { value = last.value, time = last.time, panel = panel }
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

    function M.update()
        if not cfg then
            cfg, configError = api.config()
            tile = cfg and (cfg.values or {})[key]
            errorText = configError
        end
        noctalia.setUpdateInterval(cfg and 60000 or 5000)
        if not busy then refresh() end
        if fetchedAt > 0 and os.time() - fetchedAt > 180 then errorText = "Grafana unavailable" end
        render()
    end

    return M
end
