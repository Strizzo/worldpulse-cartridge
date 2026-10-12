-- Headline list and metadata details. Article bodies are not fetched.
local U = _G.ui.public
local C = U.C
local ui = require("lib.ui")
local M = {VISIBLE_ROWS = 4}
local ROW_H = 88

local function draw_detail(state, article)
    U.panel(24, 170, 672, 460, C.panel, C.red)
    U.text("ARTICLE / " .. state.feed_cursor .. " OF " .. #state.articles, 40, 184, 14, C.muted, 632, true)
    ui.lines(article.title ~= "" and article.title or "Headline not supplied", 40, 220, 632, 24, 6, C.paper, true)
    U.rule(40, 418, 632)
    U.text(ui.short_domain(article.domain), 40, 434, 18, C.teal, 632, true)
    U.text(ui.format_date(article.date), 40, 464, 16, C.muted, 632)
    U.text((article.country ~= "" and article.country or "Country not supplied") .. " / " ..
        (article.language ~= "" and article.language or "Language not supplied"), 40, 494, 16, C.muted, 632)
    ui.lines(article.url ~= "" and article.url or "Article URL not supplied", 40, 528, 632, 14, 2, C.muted)
    U.text("GDELT headline metadata. Article body is not included.", 40, 602, 14, C.quiet, 632)
end

function M.draw(state)
    local articles = state.articles or {}
    if state.feed_detail and articles[state.feed_cursor] then
        draw_detail(state, articles[state.feed_cursor])
    elseif #articles == 0 then
        local loading = state.sources.articles.status == "loading"
        local body = state.articles and "GDELT returned an empty article list for the past 24 hours. Y refreshes."
            or loading and "Headlines are loading. You can switch views while the request is pending."
            or "The news source has not returned usable data. Y retries; saved headlines appear when available."
        U.empty(loading and "Loading headlines" or "No headlines", body, 230)
    else
        U.text("24h source window / headlines", 24, 158, 14, C.muted, 500)
        U.text(string.format("%d / %d", state.feed_cursor, #articles), 580, 158, 14, C.muted, 116)
        for index = state.feed_scroll + 1, math.min(#articles, state.feed_scroll + M.VISIBLE_ROWS) do
            local article = articles[index]
            local y = 184 + (index - state.feed_scroll - 1) * ROW_H
            local fg, secondary = U.row(24, y, 672, ROW_H - 6, index == state.feed_cursor)
            U.text(ui.short_domain(article.domain), 40, y + 8, 14, secondary, 388, true)
            U.text(ui.format_date(article.date), 468, y + 8, 14, secondary, 212)
            ui.lines(article.title ~= "" and article.title or "Headline not supplied", 40, y + 31, 632, 18, 2, fg, true)
        end
        local selected = articles[state.feed_cursor]
        U.panel(24, 548, 672, 84, C.panel2)
        U.text((selected.country ~= "" and selected.country or "Country not supplied") .. " / " ..
            (selected.language ~= "" and selected.language or "Language not supplied"), 40, 562, 16, C.muted, 632)
        U.text("A opens headline details and source URL.", 40, 602, 14, C.paper, 632)
    end
    ui.source_line(state, "articles")
end

function M.on_input(state, button, action)
    if action ~= "press" and action ~= "repeat" then return end
    -- Refresh is available even when the feed is empty or has failed.
    if button == "y" then return "refresh" end
    if button == "b" then state.feed_detail = false; return end
    local n = state.articles and #state.articles or 0
    if n == 0 then return end
    if button == "a" then state.feed_detail = true
    elseif button == "dpad_down" then state.feed_cursor = math.min(n, state.feed_cursor + 1)
    elseif button == "dpad_up" then state.feed_cursor = math.max(1, state.feed_cursor - 1) end
    if state.feed_cursor > state.feed_scroll + M.VISIBLE_ROWS then state.feed_scroll = state.feed_cursor - M.VISIBLE_ROWS
    elseif state.feed_cursor <= state.feed_scroll then state.feed_scroll = state.feed_cursor - 1 end
end

return M
