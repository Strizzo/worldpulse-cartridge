-- Capture the runtime UI before the app's local ui shadows it.
local U = _G.ui.public
local C = U.C
local M = {public = U}

function M.tone_color(tone)
    if type(tone) ~= "number" then return C.quiet end
    if tone < -3 then return C.red end
    if tone > 3 then return C.green end
    return C.gold
end

function M.tone_label(tone)
    if type(tone) ~= "number" then return "Sentiment not supplied" end
    if tone < -3 then return "Negative sentiment" end
    if tone > 3 then return "Positive sentiment" end
    return "Neutral sentiment"
end

function M.lines(value, x, y, width, size, limit, color, bold)
    for i, line in ipairs(U.wrap(value or "", width, size, limit, bold)) do
        U.text(line, x, y + (i - 1) * (size + 6), size, color, width, bold)
    end
end

function M.format_date(value)
    if type(value) ~= "string" then return "Time not supplied" end
    local year, month, day, hour, minute = value:match("^(%d%d%d%d)(%d%d)(%d%d)T(%d%d)(%d%d)")
    if not year then return "Time not supplied" end
    return day .. "/" .. month .. " " .. hour .. ":" .. minute .. " UTC"
end

function M.short_domain(domain)
    if not domain or domain == "" then return "Source not supplied" end
    return domain:gsub("^www%.", "")
end

function M.source_status(state, kind)
    local source = state.sources[kind]
    local value = state[kind]
    local has_data = value ~= nil
    if source.status == "loading" then return has_data and "Refreshing saved data" or "Loading data" end
    if source.status == "queued" then
        return (has_data and "Saved data / queued" or "Queued") ..
            (source.waiting_for and " / " .. source.waiting_for or "")
    end
    if source.status == "error" then
        return (has_data and "Saved data / " or "Unavailable / ") .. source.error
    end
    if source.status == "cached" then
        return source.updated_at and "Saved data / " .. os.date("%d/%m %H:%M", source.updated_at)
            or "Saved data / update time unknown"
    end
    if source.updated_at then return "Updated " .. os.date("%H:%M", source.updated_at) end
    return "Not loaded"
end

function M.source_line(state, kind, y)
    local names = {events = "GDELT GEO", articles = "GDELT DOC", iss = "ISS"}
    local color = state.sources[kind].status == "error" and C.red or C.muted
    U.text(names[kind] .. " / " .. M.source_status(state, kind), 24, y or 648, 14, color, 672)
end

return M
