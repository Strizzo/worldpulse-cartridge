-- screens/feed.lua — Scrollable earthquake feed

local ui = require("lib.ui")

local M = {}

local VISIBLE_ROWS = 12
local ROW_H = 52
local CONTENT_Y = 42

--- Draw the feed screen
function M.draw(state)
    local W = 720
    local quakes = state.quakes or {}

    -- Column headers
    screen.draw_rect(0, CONTENT_Y, W, 18, {color = ui.colors.panel, filled = true})
    screen.draw_text("MAG", 12, CONTENT_Y + 2, {color = ui.colors.text_dim, size = 10, bold = true})
    screen.draw_text("LOCATION", 80, CONTENT_Y + 2, {color = ui.colors.text_dim, size = 10, bold = true})
    screen.draw_text("DEPTH", 520, CONTENT_Y + 2, {color = ui.colors.text_dim, size = 10, bold = true})
    screen.draw_text("TIME", 620, CONTENT_Y + 2, {color = ui.colors.text_dim, size = 10, bold = true})

    if #quakes == 0 then
        screen.draw_text("No earthquake data", W / 2 - 60, 300, {color = ui.colors.text_dim, size = 14})
        return
    end

    local list_y = CONTENT_Y + 20
    local start_idx = state.feed_scroll + 1
    local end_idx = math.min(#quakes, start_idx + VISIBLE_ROWS - 1)

    for i = start_idx, end_idx do
        local q = quakes[i]
        local ry = list_y + (i - start_idx) * ROW_H
        local is_selected = (i == state.feed_cursor)

        -- Row background
        local row_bg = is_selected and ui.colors.panel_b or (i % 2 == 0 and ui.colors.panel or ui.colors.bg)
        screen.draw_rect(0, ry, W, ROW_H, {color = row_bg, filled = true})

        if is_selected then
            screen.draw_rect(0, ry, 3, ROW_H, {color = ui.colors.accent, filled = true})
        end

        -- Magnitude badge
        local mc = ui.mag_color(q.mag)
        screen.draw_pill(string.format("%.1f", q.mag), 10, ry + 8, mc[1], mc[2], mc[3], {
            text_color = {10, 10, 10}, size = 13,
        })

        -- Severity label
        screen.draw_text(ui.mag_label(q.mag), 10, ry + 30, {color = mc, size = 9, bold = true})

        -- Location
        screen.draw_text(q.place, 80, ry + 8, {color = ui.colors.text, size = 12, max_width = 430})

        -- Coordinates
        screen.draw_text(
            string.format("%.2f, %.2f", q.lat, q.lon),
            80, ry + 28, {color = ui.colors.text_dim, size = 10}
        )

        -- Depth
        screen.draw_text(string.format("%.0f km", q.depth), 520, ry + 8, {
            color = ui.colors.text_dim, size = 11,
        })

        -- Time
        screen.draw_text(ui.time_ago(q.time), 620, ry + 8, {
            color = ui.colors.text_dim, size = 11,
        })

        -- Separator
        screen.draw_line(0, ry + ROW_H - 1, W, ry + ROW_H - 1, {color = {20, 30, 40}, width = 1})
    end

    -- Scroll indicator
    if #quakes > VISIBLE_ROWS then
        local bar_h = 620
        local thumb_h = math.max(20, bar_h * VISIBLE_ROWS / #quakes)
        local thumb_y = list_y + (bar_h - thumb_h) * state.feed_scroll / math.max(1, #quakes - VISIBLE_ROWS)
        screen.draw_rect(W - 4, list_y, 3, bar_h, {color = ui.colors.panel, filled = true, radius = 1})
        screen.draw_rect(W - 4, thumb_y, 3, thumb_h, {color = ui.colors.accent_dim, filled = true, radius = 1})
    end

    -- Count
    local count_text = string.format("%d of %d events", end_idx, #quakes)
    local cw = screen.get_text_width(count_text, 10, false)
    screen.draw_text(count_text, W - cw - 12, CONTENT_Y + 2, {color = ui.colors.text_dim, size = 10})
end

--- Handle input on feed screen
function M.on_input(state, button, action)
    if action ~= "press" and action ~= "repeat" then return nil end

    local n = state.quakes and #state.quakes or 0
    if n == 0 then return nil end

    if button == "dpad_down" then
        state.feed_cursor = math.min(n, state.feed_cursor + 1)
        -- Scroll to keep cursor visible
        if state.feed_cursor > state.feed_scroll + VISIBLE_ROWS then
            state.feed_scroll = state.feed_cursor - VISIBLE_ROWS
        end
    elseif button == "dpad_up" then
        state.feed_cursor = math.max(1, state.feed_cursor - 1)
        if state.feed_cursor <= state.feed_scroll then
            state.feed_scroll = state.feed_cursor - 1
        end
    elseif button == "y" then
        return "refresh"
    end

    return nil
end

return M
