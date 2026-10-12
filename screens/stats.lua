-- Counts describe the returned GDELT sample, not all world events.
local U = _G.ui.public
local C = U.C
local ui = require("lib.ui")
local M = {}

function M.draw(state)
    local summary = state.event_summary or {total = 0, negative = 0, neutral = 0, positive = 0, unscored = 0, countries = {}}
    U.metric(24, 168, 214, 112, "Locations", state.events and summary.total or "--", "places", C.teal)
    U.metric(250, 168, 214, 112, "Headlines", state.articles and #state.articles or "--", "articles", C.paper)
    U.metric(476, 168, 220, 112, "Country labels", state.events and #summary.countries or "--", "supplied", C.gold)

    U.panel(24, 292, 672, 142, C.panel)
    U.text("ARTICLE SENTIMENT / RETURNED LOCATIONS", 40, 305, 14, C.muted, 632, true)
    local categories = {{"Negative", summary.negative, C.red}, {"Neutral", summary.neutral, C.gold},
        {"Positive", summary.positive, C.green}, {"Not supplied", summary.unscored or 0, C.quiet}}
    if state.events and summary.total > 0 then
        local x = 40
        for _, category in ipairs(categories) do
            local width = category[2] / summary.total * 632
            U.rect(x, 334, width, 14, category[3]); x = x + width
        end
    else
        U.rect(40, 334, 632, 14, C.panel2)
    end
    for i, category in ipairs(categories) do
        local x, y = 40 + ((i - 1) % 2) * 320, 361 + math.floor((i - 1) / 2) * 28
        U.rect(x, y + 4, 8, 8, category[3])
        U.text(category[1], x + 20, y, 14, C.muted, 214)
        U.text(state.events and tostring(category[2]) or "--", x + 248, y, 14, C.paper, 64, true)
    end

    U.panel(24, 446, 420, 186, C.panel)
    U.text("COUNTRY LABELS / PLACE COUNT", 40, 459, 14, C.muted, 388, true)
    local countries = summary.countries
    for i = 1, math.min(4, #countries) do
        local country, y = countries[i], 490 + (i - 1) * 32
        U.text(country.code, 40, y, 16, C.paper, 152, true)
        U.rect(210, y + 6, country.count / countries[1].count * 154, 8, C.teal)
        U.text(country.count, 378, y, 16, C.muted, 48)
    end
    if #countries == 0 then
        ui.lines(state.events and "Country labels were not supplied for this sample." or "No location data loaded.",
            40, 502, 388, 16, 3, C.muted)
    end

    U.panel(456, 446, 240, 186, C.panel)
    U.text("ISS / LAST SAMPLE", 472, 459, 14, C.muted, 208, true)
    if state.iss then
        U.text(string.format("LAT  %.3f", state.iss.lat), 472, 495, 18, C.paper, 208, true)
        U.text(string.format("LON  %.3f", state.iss.lon), 472, 528, 18, C.paper, 208, true)
        U.text(state.iss.timestamp and os.date("!%H:%M:%S UTC", state.iss.timestamp) or "Sample time unknown", 472, 567, 14, C.muted, 208)
        U.text(state.sources.iss.status == "error" and "Update unavailable" or "Updates every 15s", 472, 604, 14, C.muted, 208)
    else
        ui.lines(ui.source_status(state, "iss"), 472, 500, 208, 16, 4, C.muted)
    end
    ui.source_line(state, "events")
end

function M.on_input(state, button, action)
    if (action == "press" or action == "repeat") and button == "y" then return "refresh" end
end

return M
