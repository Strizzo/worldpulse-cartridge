-- screens/stats.lua — Global intelligence statistics

local ui = require("lib.ui")

local M = {}

function M.draw(state)
    local W = 720
    local events = state.events or {}
    local summary = state.event_summary or {total = 0, negative = 0, neutral = 0, positive = 0, countries = {}}
    local cy = 46

    -- Top row: 3 big stat cards
    local cw = 228
    local ch = 100

    -- Total Events
    local py = ui.draw_panel(4, cy, cw, ch, "EVENTS TRACKED")
    screen.draw_text(tostring(summary.total), 16, py + 4, {
        color = ui.colors.accent, size = 40, bold = true,
    })
    screen.draw_text("geolocated signals", 16, py + 48, {color = ui.colors.text_dim, size = 10})
    screen.draw_text("last 24 hours", 16, py + 62, {color = ui.colors.text_dim, size = 10})

    -- Negative/Critical
    py = ui.draw_panel(4 + cw + 4, cy, cw, ch, "NEGATIVE TONE")
    screen.draw_text(tostring(summary.negative), 16 + cw + 4, py + 4, {
        color = ui.colors.tone_neg, size = 40, bold = true,
    })
    local neg_pct = summary.total > 0 and math.floor(summary.negative / summary.total * 100) or 0
    screen.draw_text(neg_pct .. "% of events", 16 + cw + 4, py + 48, {
        color = ui.colors.text_dim, size = 10,
    })
    screen.draw_text("conflict, crisis, tension", 16 + cw + 4, py + 62, {
        color = ui.colors.text_dim, size = 10,
    })

    -- Positive
    py = ui.draw_panel(4 + (cw + 4) * 2, cy, cw, ch, "POSITIVE TONE")
    screen.draw_text(tostring(summary.positive), 16 + (cw + 4) * 2, py + 4, {
        color = ui.colors.tone_pos, size = 40, bold = true,
    })
    local pos_pct = summary.total > 0 and math.floor(summary.positive / summary.total * 100) or 0
    screen.draw_text(pos_pct .. "% of events", 16 + (cw + 4) * 2, py + 48, {
        color = ui.colors.text_dim, size = 10,
    })
    screen.draw_text("diplomacy, cooperation", 16 + (cw + 4) * 2, py + 62, {
        color = ui.colors.text_dim, size = 10,
    })

    -- Sentiment distribution bar
    cy = cy + ch + 8
    py = ui.draw_panel(4, cy, W - 8, 60, "SENTIMENT DISTRIBUTION")

    local bar_x = 16
    local bar_w = W - 40
    local bar_y = py + 8
    local bar_h = 20

    if summary.total > 0 then
        local neg_w = math.max(1, summary.negative / summary.total * bar_w)
        local neu_w = math.max(1, summary.neutral / summary.total * bar_w)
        local pos_w = math.max(1, summary.positive / summary.total * bar_w)

        screen.draw_rect(bar_x, bar_y, neg_w, bar_h, {color = ui.colors.tone_neg, filled = true, radius = 2})
        screen.draw_rect(bar_x + neg_w, bar_y, neu_w, bar_h, {color = ui.colors.tone_neu, filled = true})
        screen.draw_rect(bar_x + neg_w + neu_w, bar_y, pos_w, bar_h, {color = ui.colors.tone_pos, filled = true, radius = 2})

        -- Labels below bar
        screen.draw_text("Negative " .. neg_pct .. "%", bar_x, bar_y + bar_h + 4, {
            color = ui.colors.tone_neg, size = 9,
        })
        local neu_pct = 100 - neg_pct - pos_pct
        local neu_label = "Neutral " .. neu_pct .. "%"
        local nlw = screen.get_text_width(neu_label, 9, false)
        screen.draw_text(neu_label, bar_x + bar_w / 2 - nlw / 2, bar_y + bar_h + 4, {
            color = ui.colors.tone_neu, size = 9,
        })
        local pos_label = "Positive " .. pos_pct .. "%"
        local plw = screen.get_text_width(pos_label, 9, false)
        screen.draw_text(pos_label, bar_x + bar_w - plw, bar_y + bar_h + 4, {
            color = ui.colors.tone_pos, size = 9,
        })
    else
        screen.draw_text("No data", bar_x, bar_y + 4, {color = ui.colors.text_dim, size = 12})
    end

    -- Top countries
    cy = cy + 68
    py = ui.draw_panel(4, cy, W - 8, 240, "TOP ACTIVE REGIONS")

    local countries = summary.countries or {}
    local max_count = countries[1] and countries[1].count or 1
    local row_y = py + 4
    local col_w = (W - 40) / 2
    local rows_per_col = 12

    for i = 1, math.min(rows_per_col * 2, #countries) do
        local c = countries[i]
        local col = i <= rows_per_col and 0 or 1
        local row = i <= rows_per_col and (i - 1) or (i - rows_per_col - 1)
        local rx = 16 + col * col_w
        local ry = row_y + row * 18

        -- Rank
        screen.draw_text(string.format("%2d.", i), rx, ry, {color = ui.colors.text_dim, size = 10})

        -- Country code
        screen.draw_text(c.code, rx + 28, ry, {color = ui.colors.accent, size = 10, bold = true})

        -- Bar
        local bw = math.max(2, c.count / max_count * 150)
        screen.draw_rect(rx + 75, ry + 3, bw, 8, {color = ui.colors.accent_dim, filled = true, radius = 2})

        -- Count
        screen.draw_text(tostring(c.count), rx + 75 + bw + 6, ry, {color = ui.colors.text_dim, size = 10})
    end

    if #countries == 0 then
        screen.draw_text("No data available", 20, row_y + 40, {color = ui.colors.text_dim, size = 12})
    end

    -- ISS info
    cy = cy + 248
    py = ui.draw_panel(4, cy, W - 8, 60, "ISS POSITION")
    if state.iss then
        screen.draw_text(string.format("LAT %.4f", state.iss.lat), 20, py + 6, {
            color = ui.colors.accent, size = 14, bold = true,
        })
        screen.draw_text(string.format("LON %.4f", state.iss.lon), 200, py + 6, {
            color = ui.colors.accent, size = 14, bold = true,
        })
        screen.draw_text("Altitude ~408 km  |  Speed ~28,000 km/h", 20, py + 28, {
            color = ui.colors.text_dim, size = 10,
        })
    else
        screen.draw_text("ISS data unavailable", 20, py + 16, {color = ui.colors.text_dim, size = 12})
    end
end

function M.on_input(state, button, action)
    if action ~= "press" and action ~= "repeat" then return nil end
    if button == "y" then return "refresh" end
    return nil
end

return M
