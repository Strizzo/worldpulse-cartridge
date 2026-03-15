-- lib/data.lua — Data fetching from GDELT and ISS

local M = {}

--- Fetch geolocated news events from GDELT
-- Returns table of events: {lat, lon, name, url, title, tone, domain, country, image}
function M.fetch_events()
    local url = "https://api.gdeltproject.org/api/v2/geo/geo?query=&mode=pointdata&format=geojson&maxpoints=200&timespan=24h"
    local resp = http.get_cached(url, 300)
    if not resp.ok then
        return nil, "GDELT GEO: HTTP " .. tostring(resp.status)
    end

    local data = json.decode(resp.body)
    if not data or not data.features then
        return nil, "GDELT GEO: bad response"
    end

    local events = {}
    for _, feat in ipairs(data.features) do
        local props = feat.properties or {}
        local geom = feat.geometry or {}
        local coords = geom.coordinates or {}
        if #coords >= 2 then
            events[#events + 1] = {
                lon     = coords[1],
                lat     = coords[2],
                name    = props.name or "",
                url     = props.url or "",
                title   = props.name or "",
                tone    = tonumber(props.tonez) or 0,
                domain  = props.domain or "",
                country = props.countrycode or "",
                image   = props.shareimage or "",
                count   = tonumber(props.count) or 1,
            }
        end
    end

    return events
end

--- Fetch news articles from GDELT
-- Returns table of articles: {title, url, domain, date, country, language, image}
function M.fetch_articles()
    local url = "https://api.gdeltproject.org/api/v2/doc/doc?query=&mode=artlist&maxrecords=75&format=json&sort=datedesc"
    local resp = http.get_cached(url, 300)
    if not resp.ok then
        return nil, "GDELT DOC: HTTP " .. tostring(resp.status)
    end

    local data = json.decode(resp.body)
    if not data or not data.articles then
        return nil, "GDELT DOC: bad response"
    end

    local articles = {}
    for _, art in ipairs(data.articles) do
        articles[#articles + 1] = {
            title    = art.title or "",
            url      = art.url or "",
            domain   = art.domain or "",
            date     = art.seendate or "",
            country  = art.sourcecountry or "",
            language = art.language or "",
            image    = art.socialimage or "",
        }
    end

    return articles
end

--- Fetch ISS position
function M.fetch_iss()
    local resp = http.get("http://api.open-notify.org/iss-now.json")
    if not resp.ok then
        return nil, "ISS: HTTP " .. tostring(resp.status)
    end

    local data = json.decode(resp.body)
    if not data or not data.iss_position then
        return nil, "ISS: bad response"
    end

    return {
        lat = tonumber(data.iss_position.latitude) or 0,
        lon = tonumber(data.iss_position.longitude) or 0,
        timestamp = data.timestamp or os.time(),
    }
end

--- Summarize events for the stats screen
function M.summarize_events(events)
    if not events or #events == 0 then
        return {total = 0, negative = 0, neutral = 0, positive = 0, countries = {}}
    end

    local total = #events
    local negative, neutral, positive = 0, 0, 0
    local country_counts = {}

    for _, ev in ipairs(events) do
        if ev.tone < -3 then
            negative = negative + 1
        elseif ev.tone > 3 then
            positive = positive + 1
        else
            neutral = neutral + 1
        end

        local c = ev.country
        if c and c ~= "" then
            country_counts[c] = (country_counts[c] or 0) + 1
        end
    end

    -- Top countries by event count
    local countries = {}
    for code, count in pairs(country_counts) do
        countries[#countries + 1] = {code = code, count = count}
    end
    table.sort(countries, function(a, b) return a.count > b.count end)

    return {
        total = total,
        negative = negative,
        neutral = neutral,
        positive = positive,
        countries = countries,
    }
end

return M
