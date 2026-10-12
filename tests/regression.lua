-- Pure Lua checks: all UI, HTTP, SSH and storage are in-memory mocks.
-- Run this file as the entry in a scratch copy of the app. Do not change the
-- production manifest. No network request or SSH process is created.
local native_screen = screen
local colors = _G.ui.public.C
local drawn, replies, requests, saved = {}, {}, {}, {}
local mock_clock, last_gdelt_start = 0, nil
local U = {C = colors}
local function record(value) drawn[#drawn + 1] = tostring(value or "") end
for _, method in ipairs({"rect", "rule", "panel", "tabs", "footer"}) do U[method] = function() end end
U.text = record; U.display = record
U.header = function(title, kicker, status) record(title); record(kicker); record(status) end
U.metric = function(_, _, _, _, label, value, unit) record(label); record(value); record(unit) end
U.wrap = function(value) return {tostring(value or "")} end
U.empty = function(title, body) record(title); record(body) end
U.row = function(_, _, _, _, selected) return selected and colors.bg or colors.paper, colors.muted end
_G.ui.public = U
screen = {draw_image = function() end, draw_circle = function() end,
    get_text_width = function(value, size) return #value * size / 2 end}
app = {set_idle_fps = function(value) assert(value == 1) end}
http = {
    get_async = function(url)
        local id = #requests + 1
        if url:find("api.gdeltproject.org", 1, true) then
            if last_gdelt_start then assert(mock_clock - last_gdelt_start >= 6, "GDELT starts must be globally separated by 6s") end
            last_gdelt_start = mock_clock
        end
        for _, request in ipairs(requests) do
            assert(request.url ~= url or request.done, "One physical request per source")
        end
        requests[id] = {id = id, url = url, started = mock_clock}
        return id
    end,
    poll = function()
        local result = replies; replies = {}
        for _, response in ipairs(result) do requests[response.id].done = true end
        return result
    end,
    get = function() error("Synchronous HTTP is forbidden") end,
    get_cached = function() error("Synchronous HTTP is forbidden") end,
    post = function() error("Action messages are forbidden in these checks") end,
    post_async = function() error("Action messages are forbidden in these checks") end,
}
local function respond(id, value, status)
    replies[#replies + 1] = {id = id, status = status or 200,
        ok = status == nil or status == 200, body = json.encode(value)}
end
local function contains(value)
    for _, text in ipairs(drawn) do if text:find(value, 1, true) then return true end end
    return false
end
local function render()
    drawn = {}; on_render()
end

storage = {
    load = function(key)
        assert(key == "wp_data")
        return {events = {{lat = 1, lon = 2, name = "Saved place", country = "XX"}},
            articles = {{title = "Saved headline", domain = "fixture.example"}}}
    end,
    save = function(key, value) assert(key == "wp_data"); saved[#saved + 1] = value end,
}
require("main")
local real_update = on_update
local function tick(dt) mock_clock = mock_clock + dt; return real_update(dt) end
local data = require("lib.data")
local function count(kind)
    local total, last_id = 0, nil
    for _, request in ipairs(requests) do
        if request.url == data.urls[kind] then total, last_id = total + 1, request.id end
    end
    return total, last_id
end
on_init()
assert(tick(0.033333) == true)
assert(#requests == 2 and count("events") == 1 and count("articles") == 0 and count("iss") == 1,
    "Start GEO and ISS independently; queue DOC")
assert(tick(0.033333) == false, "Pending/queued requests must not animate")
for i = 1, 20 do on_input("y", "press") end
assert(tick(0.033333) == false and #requests == 2, "Refresh must coalesce")
on_input("r1", "press"); render()
assert(contains("GDELT request spacing"), "Explain queued DOC startup")
respond(1, "Fixture failure", 503)
respond(2, {iss_position = {latitude = "10", longitude = "20"}, timestamp = 1791806400})
assert(tick(0.033333) == true)
on_input("l1", "press"); render()
assert(contains("Saved place") and contains("Saved data / HTTP 503"), "Cache must be labeled after failure")
assert(contains("Sentiment not supplied"), "Missing sentiment must remain unknown")
on_input("r1", "press")
tick(6)
assert(#requests == 3 and count("articles") == 1, "DOC starts after the shared spacing gate")
respond(3, {articles = {{title = "Fresh headline", domain = "fixture.example", seendate = "20261012T120000Z"}}})
tick(0.033333); render()
assert(contains("Fresh headline"), "News success must survive a GEO failure")
assert(#saved == 1 and saved[1].events[1].name == "Saved place", "Keep failed-source cache")
assert(tick(0.033333) == false, "Idle must return false")

for i = 1, 20 do on_input("y", "press") end
tick(0.033333)
assert(#requests == 3, "Manual refresh cannot collapse GDELT spacing")
tick(6.01)
assert(#requests == 4 and count("events") == 2 and count("articles") == 1)
tick(6.01)
assert(#requests == 6 and count("articles") == 2 and count("iss") == 2)
assert(tick(21) == true, "Timeout must update the view")
for i = 1, 100 do on_input("y", "press") end
assert(tick(1) == false and #requests == 6, "Timeout slots cannot be duplicated")
respond(4, {features = {{geometry = {type = "Point", coordinates = {0, 0}}, properties = {name = "Late place"}}}})
respond(5, {articles = {{title = "Late headline"}}})
respond(6, {iss_position = {latitude = "11", longitude = "21"}})
tick(0.033333); render()
assert(contains("Fresh headline") and not contains("Late headline"), "Ignore late news results")
on_input("l1", "press"); render()
assert(contains("Saved place") and not contains("Late place"), "Ignore late GEO results")
on_input("r1", "press")

local function parse(kind, value) return data.parse(kind, {ok = true, body = json.encode(value)}) end
assert(not data.parse("events", {ok = true, body = "not json"}))
assert(not data.parse("events", {ok = true, body = string.rep("x", data.MAX_BODY + 1)}))
assert(not parse("iss", {iss_position = {latitude = "NaN", longitude = "20"}}))
assert(not parse("iss", {iss_position = {latitude = "91", longitude = "20"}}))
assert(not parse("events", {features = {{geometry = {coordinates = {200, 100}}}}}))
assert(#assert(parse("events", {features = {}})) == 0)
assert(#assert(parse("articles", {articles = {}})) == 0)
local events = assert(parse("events", {features = {{geometry = {type = "Point", coordinates = {2, 1}},
    properties = {name = "Place", html = '<a href="https://fixture.example/test">A &amp; B</a>'}}}}))
assert(events[1].title == "A & B" and events[1].url == "https://fixture.example/test" and events[1].tone == nil)
local summary = data.summarize_events(events)
assert(summary.unscored == 1 and summary.neutral == 0)
local many_events, many_articles = {}, {}
for i = 1, 250 do many_events[i] = {lat = 0, lon = 0}; many_articles[i] = {title = "Fixture " .. i} end
assert(#data.normalize_events(many_events) == 200 and #data.normalize_articles(many_articles) == 75)
local feed = require("screens.feed")
assert(feed.on_input({articles = {}, feed_cursor = 1, feed_scroll = 0}, "y", "press") == "refresh")
local bad_geo = {features = {{geometry = {type = "Point", coordinates = {0, 0}},
    properties = {name = "ERROR: An unknown error occurred - please try your query again in a few minutes."}}}}
assert(not parse("events", bad_geo))
assert(not data.normalize_events({{lat = 0, lon = 0, name = "ERROR: Cached backend error"}}))
assert(#assert(parse("events", {features = {{geometry = {type = "Point", coordinates = {0, 0}},
    properties = {name = "A genuine coordinate"}}}})) == 1, "Keep legitimate zero coordinates")
assert(not data.parse("events", {ok = false, status = 404, body = "Not found"}))

on_input("y", "press"); tick(0.033333)
assert(#requests == 8 and count("articles") == 2, "GEO + ISS may start, DOC must queue")
tick(6.01)
local before, doc_id = count("articles")
assert(before == 3)
respond(doc_id, "Rate limited", 429)
local _, iss_id = count("iss")
respond(iss_id, {iss_position = {latitude = "12", longitude = "22"}})
tick(0.033333); render()
assert(contains("queued") and contains("HTTP 429 cooldown"), "Explain the rate-limit queue")
assert(saved[#saved].gdelt_retry_at >= os.time() + 599, "Persist the shared 10-minute cooldown")
local geo_before = count("events")
local iss_before = count("iss")
for i = 1, 100 do on_input("y", "press") end
tick(100)
assert(count("articles") == before and count("events") == geo_before, "429 pauses both GDELT sources")
assert(count("iss") > iss_before, "ISS remains independent of GDELT cooldown")
tick(499)
assert(count("articles") == before, "No DOC retry before ten minutes")
tick(2)
assert(count("articles") == before + 1, "Coalesced DOC retry resumes after cooldown")
print("PASS World Pulse: global 6s GDELT spacing, queued starts, shared persisted 10m 429 cooldown, independent ISS, semantic GEO errors, bounded async, idle false, cache, late results, parser limits")
function on_init() end
function on_update() return false end
function on_render() native_screen.clear(18, 22, 24) end
