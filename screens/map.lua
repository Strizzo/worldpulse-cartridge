-- screens/map.lua — World map with news event markers

local ui = require("lib.ui")
local geo = require("lib.geo")

local M = {}

function M.draw(state)
    -- Draw map background
    geo.draw_map()

    -- News event markers
    if state.events then
        local pulse = (math.sin(state.anim_time * 3) + 1) / 2
        for i, ev in ipairs(state.events) do
            local color = ui.tone_color(ev.tone)
            local size = math.max(2, math.min(5, (ev.count or 1)))

            if state.screen == "map" and i == state.map_cursor then
                geo.draw_marker(ev.lon, ev.lat, color, size + 2, pulse)
            else
                geo.draw_marker(ev.lon, ev.lat, color, size, nil)
            end
        end
    end

    -- ISS position
    if state.iss then
        local iss_pulse = (math.sin(state.anim_time * 5) + 1) / 2
        geo.draw_marker(state.iss.lon, state.iss.lat, ui.colors.accent, 4, iss_pulse)
        local ix, iy = geo.to_pixel(state.iss.lon, state.iss.lat)
        screen.draw_text("ISS", ix + 8, iy - 6, {color = ui.colors.accent, size = 9, bold = true})
    end

    -- Scan line
    local scan_y = geo.MAP_Y + ((state.anim_time * 30) % geo.MAP_H)
    screen.draw_line(geo.MAP_X, scan_y, geo.MAP_X + geo.MAP_W, scan_y,
        {color = {0, 50, 40}, width = 1})

    -- Bottom panels
    local panel_y = geo.MAP_Y + geo.MAP_H + 4
    local summary = state.event_summary or {total = 0, negative = 0, neutral = 0, positive = 0}

    -- Left panel: event summary
    local py = ui.draw_panel(4, panel_y, 230, 120, "GLOBAL SIGNALS (24H)")
    screen.draw_text(tostring(summary.total), 16, py + 2, {
        color = ui.colors.text, size = 32, bold = true,
    })
    screen.draw_text("events tracked", 16 + screen.get_text_width(tostring(summary.total), 32, true) + 6, py + 18, {
        color = ui.colors.text_dim, size = 11,
    })

    -- Sentiment breakdown
    local by = py + 42
    local rows = {
        {"Critical/Negative", summary.negative, ui.colors.tone_neg},
        {"Neutral", summary.neutral, ui.colors.tone_neu},
        {"Positive", summary.positive, ui.colors.tone_pos},
    }
    for _, row in ipairs(rows) do
        ui.draw_dot(24, by + 2, 3, row[3])
        screen.draw_text(row[1], 32, by - 5, {color = ui.colors.text_dim, size = 10})
        screen.draw_text(tostring(row[2]), 150, by - 5, {color = ui.colors.text, size = 10, bold = true})
        by = by + 16
    end

    -- Center panel: selected event detail
    local detail_ev = nil
    if state.events and #state.events > 0 then
        if state.map_cursor >= 1 and state.map_cursor <= #state.events then
            detail_ev = state.events[state.map_cursor]
        else
            detail_ev = state.events[1]
        end
    end

    py = ui.draw_panel(240, panel_y, 240, 120, "SELECTED EVENT")
    if detail_ev then
        local tc = ui.tone_color(detail_ev.tone)
        screen.draw_pill(ui.tone_label(detail_ev.tone), 252, py + 2, tc[1], tc[2], tc[3], {
            text_color = {10, 10, 10}, size = 11,
        })

        screen.draw_text(detail_ev.name, 252, py + 24, {
            color = ui.colors.text, size = 12, max_width = 220,
        })

        if detail_ev.domain and detail_ev.domain ~= "" then
            screen.draw_text(ui.short_domain(detail_ev.domain), 252, py + 44, {
                color = ui.colors.text_dim, size = 10,
            })
        end

        screen.draw_text(
            string.format("%.2f, %.2f", detail_ev.lat, detail_ev.lon),
            252, py + 60, {color = ui.colors.text_dim, size = 10}
        )

        if detail_ev.country and detail_ev.country ~= "" then
            screen.draw_text(detail_ev.country, 252, py + 76, {
                color = ui.colors.accent_dim, size = 10, bold = true,
            })
        end
    else
        screen.draw_text("No data", 252, py + 20, {color = ui.colors.text_dim, size = 12})
    end

    -- Right panel: top active regions
    py = ui.draw_panel(486, panel_y, 230, 120, "TOP REGIONS")
    local countries = (state.event_summary or {}).countries or {}
    local ry = py + 2
    for i = 1, math.min(6, #countries) do
        local c = countries[i]
        screen.draw_text(c.code, 498, ry, {color = ui.colors.accent, size = 11, bold = true})
        -- Bar
        local max_count = countries[1] and countries[1].count or 1
        local bar_w = math.max(2, c.count / max_count * 120)
        screen.draw_rect(540, ry + 2, bar_w, 8, {color = ui.colors.accent_dim, filled = true, radius = 2})
        screen.draw_text(tostring(c.count), 540 + bar_w + 6, ry, {
            color = ui.colors.text_dim, size = 10,
        })
        ry = ry + 16
    end
    if #countries == 0 then
        screen.draw_text("Loading...", 498, py + 20, {color = ui.colors.text_dim, size = 12})
    end

    -- Status bar
    local status_y = panel_y + 126
    if state.last_error and state.last_error ~= "" then
        screen.draw_text(state.last_error, 12, status_y, {color = ui.colors.red, size = 10})
    elseif state.loading then
        screen.draw_text("Fetching data...", 12, status_y, {color = ui.colors.text_dim, size = 10})
    else
        screen.draw_text("Updated " .. (state.last_update_str or "never"), 12, status_y, {
            color = ui.colors.text_dim, size = 10,
        })
    end

    -- Legend
    local lx = 420
    screen.draw_text("LEGEND", lx, status_y, {color = ui.colors.text_dim, size = 9})
    lx = lx + 48
    local legend = {
        {"Neg", ui.colors.tone_neg}, {"Neu", ui.colors.tone_neu},
        {"Pos", ui.colors.tone_pos}, {"ISS", ui.colors.accent},
    }
    for _, item in ipairs(legend) do
        ui.draw_dot(lx, status_y + 5, 3, item[2])
        screen.draw_text(item[1], lx + 7, status_y, {color = ui.colors.text_dim, size = 9})
        lx = lx + screen.get_text_width(item[1], 9, false) + 16
    end
end

function M.on_input(state, button, action)
    if action ~= "press" and action ~= "repeat" then return nil end

    local n = state.events and #state.events or 0

    if button == "dpad_down" then
        if n > 0 then state.map_cursor = math.min(n, state.map_cursor + 1) end
    elseif button == "dpad_up" then
        if n > 0 then state.map_cursor = math.max(1, state.map_cursor - 1) end
    elseif button == "y" then
        return "refresh"
    end

    return nil
end

return M
