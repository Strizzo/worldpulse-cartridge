-- screens/stats.lua — Statistics dashboard

local ui = require("lib.ui")

local M = {}

--- Draw the stats screen
function M.draw(state)
    local W = 720
    local quakes = state.quakes or {}
    local summary = state.quake_summary or {total = 0, max_mag = 0, avg_mag = 0, by_range = {0, 0, 0, 0}}
    local cy = 46

    -- Top row: 3 big stat cards
    local cw = 228
    local ch = 100

    -- Total Events card
    local py = ui.draw_panel(4, cy, cw, ch, "TOTAL EVENTS")
    screen.draw_text(tostring(summary.total), 16, py + 4, {
        color = ui.colors.accent, size = 40, bold = true,
    })
    screen.draw_text("in last 24 hours", 16, py + 48, {color = ui.colors.text_dim, size = 10})
    screen.draw_text("M2.5+", 16, py + 62, {color = ui.colors.text_dim, size = 10})

    -- Max Magnitude card
    py = ui.draw_panel(4 + cw + 4, cy, cw, ch, "STRONGEST")
    local mc = ui.mag_color(summary.max_mag)
    screen.draw_text(string.format("%.1f", summary.max_mag), 16 + cw + 4, py + 4, {
        color = mc, size = 40, bold = true,
    })
    screen.draw_text(ui.mag_label(summary.max_mag), 16 + cw + 4, py + 48, {
        color = mc, size = 11, bold = true,
    })
    -- Find strongest quake location
    local strongest = nil
    for _, q in ipairs(quakes) do
        if not strongest or q.mag > strongest.mag then strongest = q end
    end
    if strongest then
        screen.draw_text(strongest.place, 16 + cw + 4, py + 62, {
            color = ui.colors.text_dim, size = 10, max_width = cw - 20,
        })
    end

    -- Average Magnitude card
    py = ui.draw_panel(4 + (cw + 4) * 2, cy, cw, ch, "AVERAGE")
    screen.draw_text(string.format("%.1f", summary.avg_mag), 16 + (cw + 4) * 2, py + 4, {
        color = ui.colors.text, size = 40, bold = true,
    })
    screen.draw_text("mean magnitude", 16 + (cw + 4) * 2, py + 48, {color = ui.colors.text_dim, size = 10})

    -- Magnitude distribution bar chart
    cy = cy + ch + 8
    py = ui.draw_panel(4, cy, W - 8, 160, "MAGNITUDE DISTRIBUTION")

    local bar_x = 20
    local bar_w = (W - 60) / 4
    local bar_max_h = 110
    local bar_base = py + 130
    local max_count = math.max(1, summary.by_range[1], summary.by_range[2], summary.by_range[3], summary.by_range[4])

    local labels = {"M < 4", "M 4-5.5", "M 5.5-7", "M 7+"}
    local colors = {ui.colors.mag_low, ui.colors.mag_med, ui.colors.mag_high, ui.colors.mag_crit}

    for i = 1, 4 do
        local count = summary.by_range[i]
        local bh = math.max(2, count / max_count * bar_max_h)
        local bx = bar_x + (i - 1) * bar_w

        -- Bar
        screen.draw_rect(bx + 10, bar_base - bh, bar_w - 20, bh, {
            color = colors[i], filled = true, radius = 3,
        })

        -- Count label on top of bar
        local ct = tostring(count)
        local ctw = screen.get_text_width(ct, 12, true)
        screen.draw_text(ct, bx + bar_w / 2 - ctw / 2, bar_base - bh - 16, {
            color = colors[i], size = 12, bold = true,
        })

        -- Category label below bar
        local lw = screen.get_text_width(labels[i], 10, false)
        screen.draw_text(labels[i], bx + bar_w / 2 - lw / 2, bar_base + 4, {
            color = ui.colors.text_dim, size = 10,
        })
    end

    -- Bottom row: recent quakes sparkline-style
    cy = cy + 168
    py = ui.draw_panel(4, cy, W - 8, 140, "RECENT MAGNITUDE TIMELINE")

    if #quakes >= 2 then
        -- Build data array (reverse chronological → left=oldest, right=newest)
        local data = {}
        local count = math.min(60, #quakes)
        for i = count, 1, -1 do
            data[#data + 1] = quakes[i].mag
        end
        screen.draw_sparkline(data, 16, py + 8, W - 40, 80, {
            color = ui.colors.accent,
            baseline_color = ui.colors.accent_dim,
        })

        -- Y-axis labels
        screen.draw_text("M8", W - 28, py + 4, {color = ui.colors.text_dim, size = 8})
        screen.draw_text("M2", W - 28, py + 76, {color = ui.colors.text_dim, size = 8})

        -- X-axis
        screen.draw_text("oldest", 16, py + 92, {color = ui.colors.text_dim, size = 8})
        local nw = screen.get_text_width("newest", 8, false)
        screen.draw_text("newest", W - 40 - nw, py + 92, {color = ui.colors.text_dim, size = 8})
    else
        screen.draw_text("Not enough data for timeline", 20, py + 40, {
            color = ui.colors.text_dim, size = 12,
        })
    end

    -- ISS info panel
    cy = cy + 148
    py = ui.draw_panel(4, cy, W - 8, 70, "ISS POSITION")
    if state.iss then
        screen.draw_text(string.format("LAT %.4f", state.iss.lat), 20, py + 6, {
            color = ui.colors.accent, size = 14, bold = true,
        })
        screen.draw_text(string.format("LON %.4f", state.iss.lon), 200, py + 6, {
            color = ui.colors.accent, size = 14, bold = true,
        })
        screen.draw_text("Altitude: ~408 km | Speed: ~28,000 km/h | Crew: active", 20, py + 30, {
            color = ui.colors.text_dim, size = 10,
        })
    else
        screen.draw_text("ISS data unavailable", 20, py + 16, {color = ui.colors.text_dim, size = 12})
    end
end

--- Handle input on stats screen
function M.on_input(state, button, action)
    if action ~= "press" and action ~= "repeat" then return nil end

    if button == "y" then
        return "refresh"
    end

    return nil
end

return M
