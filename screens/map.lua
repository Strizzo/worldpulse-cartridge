-- Calm atlas: markers are indexed place mentions, not confirmed events.
local U = _G.ui.public
local C = U.C
local ui = require("lib.ui")
local geo = require("lib.geo")
local M = {}

function M.draw(state)
    local events = state.events or {}
    U.text("24h source window / " .. (state.events and tostring(#events) .. " returned locations" or "locations not loaded"),
        24, 158, 14, C.muted, 672)
    geo.draw_map()
    for i, event in ipairs(events) do
        geo.draw_marker(event.lon, event.lat, ui.tone_color(event.tone),
            math.min(5, math.max(3, math.sqrt(math.max(1, event.count or 1)))), i == state.map_cursor)
    end
    if state.iss then
        geo.draw_marker(state.iss.lon, state.iss.lat, C.teal, 4, false)
        local x, y = geo.to_pixel(state.iss.lon, state.iss.lat)
        U.text("ISS", math.min(650, x + 8), math.max(184, y - 8), 14, C.teal, 42, true)
    end
    if #events == 0 then
        U.panel(100, 286, 520, 122, C.panel)
        U.display(state.sources.events.status == "loading" and "Loading locations" or "No locations", 120, 305, 30, C.paper, 480)
        local body = state.events and "GDELT returned no matching place mentions."
            or state.sources.events.status == "error" and "The location source is unavailable. Y retries."
            or "News and stats remain available while data loads."
        ui.lines(body, 120, 357, 480, 16, 2, C.muted)
    end

    U.panel(24, 528, 672, 104, C.panel, C.red)
    local selected = events[state.map_cursor]
    if selected then
        U.text("PLACE MENTION / " .. state.map_cursor .. " OF " .. #events, 40, 540, 14, C.muted, 424, true)
        U.text(selected.name ~= "" and selected.name or "Unnamed location", 40, 566, 24, C.paper, 424, true)
        U.text(selected.domain ~= "" and ui.short_domain(selected.domain) or "Article source not supplied", 40, 604, 14, C.muted, 424)
        U.text(ui.tone_label(selected.tone), 486, 544, 14, ui.tone_color(selected.tone), 194, true)
        U.text(string.format("%.2f, %.2f", selected.lat, selected.lon), 486, 573, 16, C.paper, 194)
        U.text(selected.country ~= "" and selected.country or "Country not supplied", 486, 604, 14, C.muted, 194)
    else
        U.text("Select a place with the D-pad", 40, 548, 18, C.paper, 632, true)
        U.text("Markers show locations mentioned in indexed coverage.", 40, 587, 16, C.muted, 632)
    end
    ui.source_line(state, "events")
end

function M.on_input(state, button, action)
    if action ~= "press" and action ~= "repeat" then return end
    local n = state.events and #state.events or 0
    if button == "dpad_down" and n > 0 then state.map_cursor = math.min(n, state.map_cursor + 1)
    elseif button == "dpad_up" and n > 0 then state.map_cursor = math.max(1, state.map_cursor - 1)
    elseif button == "y" then return "refresh" end
end

return M
