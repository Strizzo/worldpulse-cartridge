-- lib/data.lua — Data fetching and parsing

local M = {}

--- Fetch earthquake data from USGS
-- Returns table of quakes: {mag, lat, lon, place, time, depth}
function M.fetch_quakes()
    local url = "https://earthquake.usgs.gov/earthquakes/feed/v1.0/summary/2.5_day.geojson"
    local resp = http.get_cached(url, 120)
    if not resp.ok then
        return nil, "USGS: HTTP " .. tostring(resp.status)
    end

    local data = json.decode(resp.body)
    if not data or not data.features then
        return nil, "USGS: bad response"
    end

    local quakes = {}
    for _, feat in ipairs(data.features) do
        local props = feat.properties or {}
        local geom = feat.geometry or {}
        local coords = geom.coordinates or {}
        quakes[#quakes + 1] = {
            mag   = props.mag or 0,
            place = props.place or "Unknown",
            time  = props.time or 0,
            lon   = coords[1] or 0,
            lat   = coords[2] or 0,
            depth = coords[3] or 0,
        }
    end

    -- Sort by time descending (most recent first)
    table.sort(quakes, function(a, b) return a.time > b.time end)

    return quakes
end

--- Fetch ISS position
-- Returns {lat, lon, timestamp}
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

--- Summarize earthquake data
function M.summarize_quakes(quakes)
    if not quakes or #quakes == 0 then
        return {total = 0, max_mag = 0, avg_mag = 0, by_range = {0, 0, 0, 0}}
    end

    local total = #quakes
    local max_mag = 0
    local sum = 0
    local by_range = {0, 0, 0, 0} -- <4, 4-5.5, 5.5-7, 7+

    for _, q in ipairs(quakes) do
        if q.mag > max_mag then max_mag = q.mag end
        sum = sum + q.mag
        if q.mag >= 7 then
            by_range[4] = by_range[4] + 1
        elseif q.mag >= 5.5 then
            by_range[3] = by_range[3] + 1
        elseif q.mag >= 4 then
            by_range[2] = by_range[2] + 1
        else
            by_range[1] = by_range[1] + 1
        end
    end

    return {
        total = total,
        max_mag = max_mag,
        avg_mag = sum / total,
        by_range = by_range,
    }
end

return M
