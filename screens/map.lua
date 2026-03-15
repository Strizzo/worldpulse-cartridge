-- screens/map.lua — World map with earthquake markers and ISS tracker

local ui = require("lib.ui")
local geo = require("lib.geo")

local M = {}

--- Draw the map screen
function M.draw(state)
    -- Draw map background
    geo.draw_map()

    -- Earthquake markers
    if state.quakes then
        local pulse = (math.sin(state.anim_time * 3) + 1) / 2  -- 0 to 1
        for i, q in ipairs(state.quakes) do
            local color = ui.mag_color(q.mag)
            local size = math.max(2, math.min(8, q.mag - 1))

            -- Selected quake gets a highlight ring
            if state.screen == "map" and i == state.map_cursor then
                geo.draw_marker(q.lon, q.lat, color, size + 2, pulse)
            else
                geo.draw_marker(q.lon, q.lat, color, size, nil)
            end
        end
    end

    -- ISS position
    if state.iss then
        local iss_pulse = (math.sin(state.anim_time * 5) + 1) / 2
        geo.draw_marker(state.iss.lon, state.iss.lat, ui.colors.accent, 4, iss_pulse)

        -- ISS label
        local ix, iy = geo.to_pixel(state.iss.lon, state.iss.lat)
        screen.draw_text("ISS", ix + 8, iy - 6, {color = ui.colors.accent, size = 9, bold = true})
    end

    -- Map overlay: scan line animation
    local scan_y = geo.MAP_Y + ((state.anim_time * 30) % geo.MAP_H)
    screen.draw_line(geo.MAP_X, scan_y, geo.MAP_X + geo.MAP_W, scan_y,
        {color = {0, 50, 40}, width = 1})

    -- Bottom data panels (below map)
    local panel_y = geo.MAP_Y + geo.MAP_H + 4

    -- Left panel: quake summary
    local summary = state.quake_summary or {total = 0, max_mag = 0, by_range = {0, 0, 0, 0}}
    local py = ui.draw_panel(4, panel_y, 230, 120, "SEISMIC ACTIVITY (24H)")
    screen.draw_text(tostring(summary.total), 16, py + 2, {
        color = ui.colors.text, size = 32, bold = true,
    })
    screen.draw_text("events", 16 + screen.get_text_width(tostring(summary.total), 32, true) + 6, py + 18, {
        color = ui.colors.text_dim, size = 11,
    })

    -- Magnitude breakdown
    local by = py + 42
    local ranges = {"M<4", "M4-5.5", "M5.5-7", "M7+"}
    local range_colors = {ui.colors.mag_low, ui.colors.mag_med, ui.colors.mag_high, ui.colors.mag_crit}
    for i = 1, 4 do
        ui.draw_dot(24, by + 2, 3, range_colors[i])
        screen.draw_text(ranges[i], 32, by - 5, {color = ui.colors.text_dim, size = 10})
        screen.draw_text(tostring(summary.by_range[i]), 80, by - 5, {color = ui.colors.text, size = 10, bold = true})
        by = by + 16
    end

    -- Center panel: selected quake detail or largest
    local detail_q = nil
    if state.quakes and #state.quakes > 0 then
        if state.map_cursor >= 1 and state.map_cursor <= #state.quakes then
            detail_q = state.quakes[state.map_cursor]
        else
            detail_q = state.quakes[1]
        end
    end

    py = ui.draw_panel(240, panel_y, 240, 120, "LATEST EVENT")
    if detail_q then
        -- Magnitude badge
        local mc = ui.mag_color(detail_q.mag)
        screen.draw_pill(string.format("M%.1f", detail_q.mag), 252, py + 2, mc[1], mc[2], mc[3], {
            text_color = {10, 10, 10}, size = 14,
        })
        screen.draw_text(ui.mag_label(detail_q.mag), 310, py + 4, {
            color = mc, size = 11, bold = true,
        })

        -- Place (truncated)
        screen.draw_text(detail_q.place, 252, py + 26, {
            color = ui.colors.text, size = 12, max_width = 220,
        })

        -- Time
        screen.draw_text(ui.time_ago(detail_q.time), 252, py + 44, {
            color = ui.colors.text_dim, size = 10,
        })

        -- Depth
        screen.draw_text("Depth: " .. string.format("%.1f km", detail_q.depth), 252, py + 58, {
            color = ui.colors.text_dim, size = 10,
        })

        -- Coordinates
        screen.draw_text(
            string.format("%.2f, %.2f", detail_q.lat, detail_q.lon),
            252, py + 72, {color = ui.colors.text_dim, size = 10}
        )
    else
        screen.draw_text("No data", 252, py + 20, {color = ui.colors.text_dim, size = 12})
    end

    -- Right panel: ISS tracker
    py = ui.draw_panel(486, panel_y, 230, 120, "ISS TRACKER")
    if state.iss then
        screen.draw_text(string.format("%.2f", state.iss.lat), 498, py + 2, {
            color = ui.colors.accent, size = 18, bold = true,
        })
        screen.draw_text("LAT", 498 + screen.get_text_width(string.format("%.2f", state.iss.lat), 18, true) + 6, py + 8, {
            color = ui.colors.text_dim, size = 9,
        })

        screen.draw_text(string.format("%.2f", state.iss.lon), 498, py + 28, {
            color = ui.colors.accent, size = 18, bold = true,
        })
        screen.draw_text("LON", 498 + screen.get_text_width(string.format("%.2f", state.iss.lon), 18, true) + 6, py + 34, {
            color = ui.colors.text_dim, size = 9,
        })

        -- Orbit indicator
        screen.draw_text("ORBIT ACTIVE", 498, py + 60, {color = ui.colors.green, size = 10, bold = true})

        -- Speed
        screen.draw_text("~28,000 km/h", 498, py + 76, {color = ui.colors.text_dim, size = 10})
    else
        screen.draw_text("Connecting...", 498, py + 20, {color = ui.colors.text_dim, size = 12})
    end

    -- Status bar
    local status_y = panel_y + 126
    if state.last_error and state.last_error ~= "" then
        screen.draw_text(state.last_error, 12, status_y, {color = ui.colors.red, size = 10})
    elseif state.loading then
        screen.draw_text("Fetching data...", 12, status_y, {color = ui.colors.text_dim, size = 10})
    else
        local upd = state.last_update_str or "never"
        screen.draw_text("Updated " .. upd, 12, status_y, {color = ui.colors.text_dim, size = 10})
    end

    -- Legend
    screen.draw_text("LEGEND", 420, status_y, {color = ui.colors.text_dim, size = 9})
    local lx = 468
    local legend = {{"Quake", ui.colors.orange}, {"ISS", ui.colors.accent}}
    for _, item in ipairs(legend) do
        ui.draw_dot(lx, status_y + 5, 3, item[2])
        screen.draw_text(item[1], lx + 7, status_y, {color = ui.colors.text_dim, size = 9})
        lx = lx + screen.get_text_width(item[1], 9, false) + 18
    end
end

--- Handle input on map screen
function M.on_input(state, button, action)
    if action ~= "press" and action ~= "repeat" then return nil end

    local n = state.quakes and #state.quakes or 0

    if button == "dpad_down" then
        if n > 0 then
            state.map_cursor = math.min(n, state.map_cursor + 1)
        end
    elseif button == "dpad_up" then
        if n > 0 then
            state.map_cursor = math.max(1, state.map_cursor - 1)
        end
    elseif button == "y" then
        return "refresh"
    end

    return nil
end

return M
