-- Bounded response parsing. All network requests are asynchronous in main.lua.
local M = {}
M.MAX_EVENTS = 200
M.MAX_ARTICLES = 75
M.MAX_BODY = 2 * 1024 * 1024
-- ToneAbs is a documented GDELT operator. Absolute tone > -1 includes all
-- available numeric tones without an empty query or a fabricated topic feed.
local query = "toneabs%3E-1"
M.urls = {
    events = "https://api.gdeltproject.org/api/v2/geo/geo?query=" .. query .. "&mode=pointdata&format=geojson&maxpoints=200&timespan=24h",
    articles = "https://api.gdeltproject.org/api/v2/doc/doc?query=" .. query .. "&mode=artlist&maxrecords=75&format=json&sort=datedesc&timespan=24h",
    iss = "http://api.open-notify.org/iss-now.json",
}

local function string_value(value, limit)
    if type(value) ~= "string" then return "" end
    return value:sub(1, limit or 512)
end

local function finite(value)
    local n = tonumber(value)
    if n and n == n and n ~= math.huge and n ~= -math.huge then return n end
end

local function coordinates(lat, lon)
    lat, lon = finite(lat), finite(lon)
    if lat and lon and lat >= -90 and lat <= 90 and lon >= -180 and lon <= 180 then return lat, lon end
end

local function list(value)
    return type(value) == "table" and (next(value) == nil or value[1] ~= nil)
end

local function plain(value)
    return string_value(value, 4096):gsub("<[^>]*>", " "):gsub("&amp;", "&")
        :gsub("&quot;", '"'):gsub("&#39;", "'"):gsub("&lt;", "<"):gsub("&gt;", ">")
        :gsub("%s+", " "):match("^%s*(.-)%s*$")
end

function M.normalize_events(value)
    if not list(value) then return nil end
    local result = {}
    for i = 1, math.min(#value, M.MAX_EVENTS) do
        local event = value[i]
        if type(event) == "table" then
            local lat, lon = coordinates(event.lat, event.lon)
            if string_value(event.name):upper():match("^%s*ERROR%s*:") then return nil end
            if lat then
                result[#result + 1] = {lat = lat, lon = lon,
                    name = string_value(event.name), title = string_value(event.title),
                    url = string_value(event.url, 2048), tone = finite(event.tone),
                    domain = string_value(event.domain), country = string_value(event.country),
                    count = finite(event.count), image = string_value(event.image, 2048)}
            end
        end
    end
    return result
end

function M.normalize_articles(value)
    if not list(value) then return nil end
    local result = {}
    for i = 1, math.min(#value, M.MAX_ARTICLES) do
        local article = value[i]
        if type(article) == "table" then
            result[#result + 1] = {title = string_value(article.title), url = string_value(article.url, 2048),
                domain = string_value(article.domain), date = string_value(article.date),
                country = string_value(article.country), language = string_value(article.language),
                image = string_value(article.image, 2048)}
        end
    end
    return result
end

local function parse_events(value)
    if value.error == true or (type(value.error) == "string" and value.error ~= "") then
        return nil, "Geographic source returned an error"
    end
    if not list(value.features) then return nil, "Response has no location list" end
    local events = {}
    for i = 1, math.min(#value.features, M.MAX_EVENTS) do
        local feature = value.features[i]
        if type(feature) == "table" then
            local properties = type(feature.properties) == "table" and feature.properties or {}
            -- The official legacy GKG GeoJSON service can report a backend
            -- error as a synthetic Point at (0,0), even with HTTP 200. Never
            -- treat that sentinel as geographic news or count it as a location.
            if string_value(properties.name):upper():match("^%s*ERROR%s*:") then
                return nil, "Geographic source returned an error"
            end
            local geometry = type(feature.geometry) == "table" and feature.geometry or {}
            local coords = type(geometry.coordinates) == "table" and geometry.coordinates or {}
            local lat, lon = coordinates(coords[2], coords[1])
            if lat and (not geometry.type or geometry.type == "Point") then
                -- PointData is a list of mentioned locations, not discrete events.
                -- Some responses provide article links only in the popup HTML.
                local html = string_value(properties.html, 16384)
                local url = string_value(properties.url, 2048)
                local title = string_value(properties.title)
                if url == "" then url = html:match([=[href=["'](https?://.-)["']]=]) or "" end
                if title == "" then title = string_value(plain(html:match('<a[^>]*>(.-)</a>') or "")) end
                events[#events + 1] = {
                    lat = lat, lon = lon, name = string_value(properties.name),
                    title = title, url = url, tone = finite(properties.tonez or properties.tone),
                    domain = string_value(properties.domain) ~= "" and string_value(properties.domain)
                        or (url:match("^https?://([^/]+)") or ""),
                    country = string_value(properties.countrycode or properties.country),
                    count = finite(properties.count), image = string_value(properties.shareimage, 2048),
                }
            end
        end
    end
    if #value.features > 0 and #events == 0 then return nil, "Response has no valid point coordinates" end
    return events
end

local function parse_articles(value)
    if not list(value.articles) then return nil, "Response has no article list" end
    local articles = {}
    for i = 1, math.min(#value.articles, M.MAX_ARTICLES) do
        local article = value.articles[i]
        if type(article) == "table" then
            articles[#articles + 1] = {title = article.title, url = article.url, domain = article.domain,
                date = article.seendate, country = article.sourcecountry, language = article.language,
                image = article.socialimage}
        end
    end
    return M.normalize_articles(articles)
end

local function parse_iss(value)
    local position = value.iss_position
    if type(position) ~= "table" then return nil, "Response has no ISS position" end
    local lat, lon = coordinates(position.latitude, position.longitude)
    if not lat then return nil, "Response has invalid ISS coordinates" end
    local timestamp = finite(value.timestamp)
    if timestamp and (timestamp < 0 or timestamp > os.time() + 300) then timestamp = nil end
    return {lat = lat, lon = lon, timestamp = timestamp and math.floor(timestamp)}
end

function M.parse(kind, response)
    if type(response) ~= "table" or not response.ok then
        local status = type(response) == "table" and response.status or "error"
        if kind == "events" and status == 404 then
            return nil, "Geographic endpoint unavailable (HTTP 404)"
        end
        return nil, "HTTP " .. tostring(status)
    end
    if type(response.body) ~= "string" or #response.body > M.MAX_BODY then return nil, "Response too large or missing" end
    local ok, value = pcall(json.decode, response.body)
    if not ok or type(value) ~= "table" then return nil, "Response is not valid JSON" end
    if kind == "events" then return parse_events(value) end
    if kind == "articles" then return parse_articles(value) end
    if kind == "iss" then return parse_iss(value) end
    return nil, "Unknown source"
end

function M.summarize_events(events)
    local summary = {total = 0, negative = 0, neutral = 0, positive = 0, unscored = 0, countries = {}}
    local counts = {}
    for _, event in ipairs(events or {}) do
        summary.total = summary.total + 1
        if type(event.tone) ~= "number" then summary.unscored = summary.unscored + 1
        elseif event.tone < -3 then summary.negative = summary.negative + 1
        elseif event.tone > 3 then summary.positive = summary.positive + 1
        else summary.neutral = summary.neutral + 1 end
        if event.country and event.country ~= "" then counts[event.country] = (counts[event.country] or 0) + 1 end
    end
    for code, count in pairs(counts) do summary.countries[#summary.countries + 1] = {code = code, count = count} end
    table.sort(summary.countries, function(a, b)
        return a.count == b.count and a.code < b.code or a.count > b.count
    end)
    return summary
end

return M
