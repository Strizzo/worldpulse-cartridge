-- World Pulse: a news atlas of GDELT coverage, with separate ISS samples.
local U = _G.ui.public
local C = U.C
local ui = require("lib.ui")
local data = require("lib.data")
local map_screen = require("screens.map")
local feed_screen = require("screens.feed")
local stats_screen = require("screens.stats")
local TABS = {"Atlas", "News", "Stats"}
local SCREENS = {"map", "news", "stats"}
local SOURCE_ORDER = {"events", "articles", "iss"}
local REQUEST_TIMEOUT = 20
-- All requests to the GDELT API share one start gate; ISS is independent.
local GDELT_START_GAP = 6
-- The SDK does not expose Retry-After headers. A 429 pauses both GDELT
-- sources for ten minutes, persisted across launches, without endpoint hopping.
local RATE_LIMIT_COOLDOWN = 600
local sources = {}
for _, kind in ipairs(SOURCE_ORDER) do
    sources[kind] = {status = "idle", error = "", queued = true, next_start = 0}
end
local state = {
    screen = "map", tab = 1, sources = sources, clock = 0,
    map_cursor = 1, feed_cursor = 1, feed_scroll = 0, feed_detail = false,
    poll_timer = 0, poll_interval = 300, iss_timer = 0, iss_interval = 15,
    loading = false, gdelt_next_start = 0, gdelt_cooldown_until = 0,
}

local function save_cache()
    local retry_at
    if state.gdelt_cooldown_until > state.clock then
        retry_at = os.time() + math.ceil(state.gdelt_cooldown_until - state.clock)
    end
    storage.save("wp_data", {events = state.events, articles = state.articles,
        events_at = sources.events.updated_at, articles_at = sources.articles.updated_at,
        gdelt_retry_at = retry_at})
end

local function queue_refresh(kind)
    local source = sources[kind]
    -- Repeated refreshes coalesce into one request, including during cooldown.
    if source.id or source.queued then return false end
    source.queued = true
    source.status = "queued"
    return true
end

local function start_request(kind)
    local source = sources[kind]
    if not source.queued or source.id then return false end
    local earliest = source.next_start
    if kind ~= "iss" then
        earliest = math.max(earliest, state.gdelt_next_start, state.gdelt_cooldown_until)
    end
    if state.clock < earliest then
        local reason = kind ~= "iss" and state.clock < state.gdelt_cooldown_until and "HTTP 429 cooldown"
            or kind ~= "iss" and state.clock < state.gdelt_next_start and "GDELT request spacing"
            or "Source refresh interval"
        local changed = source.status ~= "queued" or source.waiting_for ~= reason
        source.status, source.waiting_for = "queued", reason
        return changed
    end
    source.queued, source.waiting_for = false, nil
    source.next_start = state.clock + (kind == "iss" and 15 or GDELT_START_GAP)
    if not http.get_async or not http.poll then
        source.status, source.error = "error", "Async HTTP unavailable"
        return true
    end
    if kind ~= "iss" then state.gdelt_next_start = state.clock + GDELT_START_GAP end
    local ok, id = pcall(http.get_async, data.urls[kind])
    if not ok or not id then
        source.status, source.error = "error", "Could not start request"
    else
        source.id, source.started = id, state.clock
        source.status, source.error, source.timed_out = "loading", "", false
    end
    return true
end

local function accept_response(kind, response)
    local source = sources[kind]
    source.id = nil
    -- A timed-out physical request retains its slot until drained. A late result
    -- is ignored and cannot overwrite the data or create overlapping requests.
    if source.timed_out then source.timed_out = false; return end
    if response.status == 429 then
        source.error = "HTTP 429 / 10-minute cooldown"
        if kind ~= "iss" then
            state.gdelt_cooldown_until = math.max(state.gdelt_cooldown_until, state.clock + RATE_LIMIT_COOLDOWN)
            state.gdelt_next_start = math.max(state.gdelt_next_start, state.gdelt_cooldown_until)
            for _, gdelt_kind in ipairs({"events", "articles"}) do
                local queued = sources[gdelt_kind]
                if not queued.id then
                    queued.queued, queued.status, queued.waiting_for = true, "queued", "HTTP 429 cooldown"
                end
            end
            save_cache()
        else
            source.queued, source.status, source.waiting_for = true, "queued", "HTTP 429 cooldown"
            source.next_start = state.clock + RATE_LIMIT_COOLDOWN
        end
        return
    end
    local value, err = data.parse(kind, response)
    if not value then source.status, source.error = "error", err; return end
    state[kind] = value
    source.status, source.error, source.updated_at = "ready", "", os.time()
    if kind == "events" then
        state.event_summary = data.summarize_events(value)
        state.map_cursor = math.max(1, math.min(state.map_cursor, #value))
    elseif kind == "articles" then
        state.feed_cursor = math.max(1, math.min(state.feed_cursor, #value))
        state.feed_scroll = math.max(0, math.min(state.feed_scroll, #value - feed_screen.VISIBLE_ROWS))
        if #value == 0 then state.feed_detail = false end
    end
    if kind ~= "iss" then save_cache() end
end

function on_init()
    local cached = storage.load("wp_data")
    if type(cached) == "table" then
        state.events = data.normalize_events(cached.events)
        state.articles = data.normalize_articles(cached.articles)
        for _, kind in ipairs({"events", "articles"}) do
            if state[kind] then
                sources[kind].status = "cached"
                local timestamp = cached[kind .. "_at"]
                if type(timestamp) == "number" and timestamp > 0 and timestamp <= os.time() then
                    sources[kind].updated_at = math.floor(timestamp)
                end
            end
        end
        local now, retry_at = os.time(), 0
        for _, key in ipairs({"gdelt_retry_at", "events_retry_at", "articles_retry_at"}) do
            local retry = cached[key]
            if type(retry) == "number" and retry > now and retry <= now + RATE_LIMIT_COOLDOWN then
                retry_at = math.max(retry_at, retry)
            end
        end
        if retry_at > now then
            state.gdelt_cooldown_until = retry_at - now
            state.gdelt_next_start = retry_at - now
            for _, kind in ipairs({"events", "articles"}) do
                sources[kind].status, sources[kind].waiting_for = "queued", "HTTP 429 cooldown"
            end
        end
        if state.events then state.event_summary = data.summarize_events(state.events) end
    end
    if app and app.set_idle_fps then app.set_idle_fps(1) end
end

function on_update(dt)
    state.clock = state.clock + dt
    local dirty = false
    if http.poll then
        local ok, responses = pcall(http.poll)
        if ok then
            for _, response in ipairs(responses or {}) do
                for _, kind in ipairs(SOURCE_ORDER) do
                    if response.id == sources[kind].id then
                        accept_response(kind, response)
                        dirty = true
                        break
                    end
                end
            end
        else
            for _, kind in ipairs(SOURCE_ORDER) do
                local source = sources[kind]
                if source.status == "loading" then
                    source.status, source.error, source.timed_out = "error", "Could not read response", true
                    dirty = true
                end
            end
        end
    end
    for _, kind in ipairs(SOURCE_ORDER) do
        local source = sources[kind]
        if source.status == "loading" and state.clock - source.started >= REQUEST_TIMEOUT then
            source.status, source.error, source.timed_out = "error", "Request timed out", true
            dirty = true
        end
    end
    state.poll_timer = state.poll_timer + dt
    if state.poll_timer >= state.poll_interval then
        state.poll_timer = 0
        queue_refresh("events"); queue_refresh("articles")
    end
    state.iss_timer = state.iss_timer + dt
    if state.iss_timer >= state.iss_interval then state.iss_timer = 0; queue_refresh("iss") end
    state.loading = false
    for _, kind in ipairs(SOURCE_ORDER) do
        dirty = start_request(kind) or dirty
        if sources[kind].status == "loading" or sources[kind].queued then state.loading = true end
    end
    -- No animation, fabricated readiness, synchronous I/O, or idle redraw loop.
    return dirty
end

function on_input(button, action)
    if action ~= "press" and action ~= "repeat" then return end
    if button == "r1" or button == "l1" then
        state.tab = (state.tab - 1 + (button == "r1" and 1 or -1)) % #TABS + 1
        state.screen, state.feed_detail = SCREENS[state.tab], false
        return
    end
    local result
    if state.screen == "map" then result = map_screen.on_input(state, button, action)
    elseif state.screen == "news" then result = feed_screen.on_input(state, button, action)
    elseif state.screen == "stats" then result = stats_screen.on_input(state, button, action) end
    if result == "refresh" then
        for _, kind in ipairs(SOURCE_ORDER) do queue_refresh(kind) end
        state.poll_timer, state.iss_timer = 0, 0
    end
end

function on_render()
    local kind = state.screen == "news" and "articles" or "events"
    local source = sources[kind]
    U.header("World Pulse", "NEWS ATLAS / GDELT COVERAGE", source.status == "loading" and "Updating"
        or source.status == "queued" and "Refresh queued" or source.status == "error" and "Source unavailable" or source.status == "cached" and "Saved data"
        or source.status == "ready" and "Source updated" or "Not loaded",
        source.status == "error" and C.red or C.muted)
    U.tabs(TABS, state.tab)
    if state.screen == "map" then map_screen.draw(state)
    elseif state.screen == "news" then feed_screen.draw(state)
    elseif state.screen == "stats" then stats_screen.draw(state) end
    if state.screen == "news" and state.feed_detail then
        U.footer({{"L1/R1", "View"}, {"D-PAD", "Article"}, {"B", "Back"}, {"Y", "Refresh"}})
    else
        local hints = {{"L1/R1", "View"}, {"Y", "Refresh"}}
        if state.screen ~= "stats" then hints[#hints + 1] = {"D-PAD", "Select"} end
        if state.screen == "news" then hints[#hints + 1] = {"A", "Details"} end
        U.footer(hints)
    end
end
