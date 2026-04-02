-- screens/feed.lua — Global news article feed

local ui = require("lib.ui")

local M = {}

local VISIBLE_ROWS = 11
local ROW_H = 58
local CONTENT_Y = 42

function M.draw(state)
    local W = 720
    local articles = state.articles or {}

    -- Column headers
    screen.draw_rect(0, CONTENT_Y, W, 18, {color = ui.colors.panel, filled = true})
    screen.draw_text("SOURCE", 12, CONTENT_Y + 2, {color = ui.colors.text_dim, size = 10, bold = true})
    screen.draw_text("HEADLINE", 160, CONTENT_Y + 2, {color = ui.colors.text_dim, size = 10, bold = true})
    screen.draw_text("TIME", 640, CONTENT_Y + 2, {color = ui.colors.text_dim, size = 10, bold = true})

    if #articles == 0 then
        screen.draw_text("No articles loaded", W / 2 - 60, 300, {color = ui.colors.text_dim, size = 14})
        return
    end

    local list_y = CONTENT_Y + 20
    local start_idx = state.feed_scroll + 1
    local end_idx = math.min(#articles, start_idx + VISIBLE_ROWS - 1)

    for i = start_idx, end_idx do
        local art = articles[i]
        local ry = list_y + (i - start_idx) * ROW_H
        local is_selected = (i == state.feed_cursor)

        -- Row background
        local row_bg = is_selected and ui.colors.panel_b or (i % 2 == 0 and ui.colors.panel or ui.colors.bg)
        screen.draw_rect(0, ry, W, ROW_H, {color = row_bg, filled = true})

        if is_selected then
            screen.draw_rect(0, ry, 3, ROW_H, {color = ui.colors.accent, filled = true})
        end

        -- Source domain
        local domain = ui.short_domain(art.domain)
        screen.draw_text(domain, 12, ry + 8, {color = ui.colors.accent, size = 11, bold = true, max_width = 140})

        -- Country
        if art.country and art.country ~= "" then
            screen.draw_text(art.country, 12, ry + 26, {
                color = ui.colors.text_dim, size = 9, max_width = 140,
            })
        end

        -- Language pill
        if art.language and art.language ~= "" then
            local lang = art.language:sub(1, 3):upper()
            screen.draw_pill(lang, 12, ry + 40, 30, 45, 55, {
                text_color = ui.colors.text_dim, size = 8,
            })
        end

        -- Headline (single line, truncated with ..)
        screen.draw_text(art.title, 160, ry + 14, {
            color = ui.colors.text, size = 13, max_width = 470,
        })

        -- Time
        screen.draw_text(ui.format_date(art.date), 640, ry + 8, {
            color = ui.colors.text_dim, size = 10,
        })

        -- Separator
        screen.draw_line(0, ry + ROW_H - 1, W, ry + ROW_H - 1, {color = {20, 30, 40}, width = 1})
    end

    -- Scroll indicator
    if #articles > VISIBLE_ROWS then
        local bar_h = 620
        local thumb_h = math.max(20, bar_h * VISIBLE_ROWS / #articles)
        local thumb_y = list_y + (bar_h - thumb_h) * state.feed_scroll / math.max(1, #articles - VISIBLE_ROWS)
        screen.draw_rect(W - 4, list_y, 3, bar_h, {color = ui.colors.panel, filled = true, radius = 1})
        screen.draw_rect(W - 4, thumb_y, 3, thumb_h, {color = ui.colors.accent_dim, filled = true, radius = 1})
    end

    -- Count
    local count_text = string.format("%d of %d articles", end_idx, #articles)
    local cw = screen.get_text_width(count_text, 10, false)
    screen.draw_text(count_text, W - cw - 12, CONTENT_Y + 2, {color = ui.colors.text_dim, size = 10})
end

function M.on_input(state, button, action)
    if action ~= "press" and action ~= "repeat" then return nil end

    local n = state.articles and #state.articles or 0
    if n == 0 then return nil end

    if button == "dpad_down" then
        state.feed_cursor = math.min(n, state.feed_cursor + 1)
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
