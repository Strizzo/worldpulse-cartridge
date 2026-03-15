-- World Pulse — Global earthquake monitor and intelligence dashboard
-- Real-time seismic data from USGS + ISS tracking

local ui = require("lib.ui")
local geo = require("lib.geo")
local data = require("lib.data")
local map_screen = require("screens.map")
local feed_screen = require("screens.feed")
local stats_screen = require("screens.stats")

-- ── State ──────────────────────────────────────────────────────────────────

local TABS = {"MAP", "FEED", "STATS"}

local state = {
    screen = "boot",
    tab = 1,  -- 1=map, 2=feed, 3=stats

    -- Boot sequence
    boot_time = 0,
    boot_phase = 0,
    boot_sources = {
        {name = "USGS EARTHQUAKE DATA", status = "WAIT", delay = 0.4},
        {name = "ISS TRACKING API",     status = "WAIT", delay = 0.8},
        {name = "MAP RENDERER",         status = "WAIT", delay = 1.2},
        {name = "SIGNAL PROCESSOR",     status = "WAIT", delay = 1.6},
    },

    -- Data
    quakes = nil,
    iss = nil,
    quake_summary = nil,

    -- Timers
    anim_time = 0,
    poll_timer = 0,
    poll_interval = 120,   -- quakes every 2 min
    iss_timer = 0,
    iss_interval = 15,     -- ISS every 15 sec

    -- UI state
    map_cursor = 1,
    feed_cursor = 1,
    feed_scroll = 0,

    -- Status
    loading = false,
    last_error = "",
    last_update_str = "never",
    needs_initial_fetch = false,
}

-- ── Data fetching ──────────────────────────────────────────────────────────

local function fetch_all()
    state.loading = true
    state.last_error = ""

    local quakes, err = data.fetch_quakes()
    if quakes then
        state.quakes = quakes
        state.quake_summary = data.summarize_quakes(quakes)
        state.last_update_str = os.date("%H:%M:%S")
    else
        state.last_error = err or "Fetch failed"
    end

    local iss, iss_err = data.fetch_iss()
    if iss then
        state.iss = iss
    elseif not state.last_error or state.last_error == "" then
        state.last_error = iss_err or "ISS fetch failed"
    end

    state.loading = false
end

local function fetch_iss_only()
    local iss, _ = data.fetch_iss()
    if iss then state.iss = iss end
end

-- ── Lifecycle ──────────────────────────────────────────────────────────────

function on_init()
    -- Try to load cached data
    local cached = storage.load("wp_quakes")
    if cached and cached.quakes then
        state.quakes = cached.quakes
        state.quake_summary = data.summarize_quakes(cached.quakes)
    end
end

function on_update(dt)
    state.anim_time = state.anim_time + dt

    if state.screen == "boot" then
        state.boot_time = state.boot_time + dt

        -- Update boot source statuses
        for _, src in ipairs(state.boot_sources) do
            if state.boot_time >= src.delay and src.status == "WAIT" then
                src.status = "OK"
            end
        end

        -- After boot sequence, transition to map and start fetching
        if state.boot_time >= 2.5 then
            state.screen = "map"
            state.needs_initial_fetch = true
        end
        return
    end

    -- Deferred initial fetch (after boot)
    if state.needs_initial_fetch then
        state.needs_initial_fetch = false
        fetch_all()
        -- Cache quake data
        if state.quakes then
            storage.save("wp_quakes", {quakes = state.quakes})
        end
        return
    end

    -- Periodic quake polling
    state.poll_timer = state.poll_timer + dt
    if state.poll_timer >= state.poll_interval then
        state.poll_timer = 0
        fetch_all()
        if state.quakes then
            storage.save("wp_quakes", {quakes = state.quakes})
        end
    end

    -- More frequent ISS polling
    state.iss_timer = state.iss_timer + dt
    if state.iss_timer >= state.iss_interval then
        state.iss_timer = 0
        fetch_iss_only()
    end
end

function on_input(button, action)
    if state.screen == "boot" then
        -- Skip boot on any press
        if action == "press" then
            state.screen = "map"
            state.needs_initial_fetch = true
        end
        return
    end

    if action == "press" or action == "repeat" then
        -- Tab switching with L1/R1
        if button == "r1" then
            state.tab = state.tab % #TABS + 1
            state.screen = string.lower(TABS[state.tab])
            return
        elseif button == "l1" then
            state.tab = (state.tab - 2) % #TABS + 1
            state.screen = string.lower(TABS[state.tab])
            return
        end
    end

    -- Delegate to current screen
    local result = nil
    if state.screen == "map" then
        result = map_screen.on_input(state, button, action)
    elseif state.screen == "feed" then
        result = feed_screen.on_input(state, button, action)
    elseif state.screen == "stats" then
        result = stats_screen.on_input(state, button, action)
    end

    if result == "refresh" then
        fetch_all()
        if state.quakes then
            storage.save("wp_quakes", {quakes = state.quakes})
        end
    end
end

-- ── Boot screen rendering ──────────────────────────────────────────────────

local function draw_boot()
    local W, H = 720, 720
    local cx, cy = W / 2, H / 2 - 60

    -- Animated reticle
    local pulse = (math.sin(state.boot_time * 4) + 1) / 2
    local ring_r = 60 + pulse * 10
    screen.draw_circle(cx, cy, ring_r, 0, 30 + pulse * 20, 25 + pulse * 15)
    screen.draw_circle(cx, cy, ring_r - 2, 10, 15, 20)

    -- Cross-hairs
    local ch_len = 20
    screen.draw_line(cx - ring_r - ch_len, cy, cx - ring_r + 8, cy,
        {color = ui.colors.accent_dim, width = 1})
    screen.draw_line(cx + ring_r - 8, cy, cx + ring_r + ch_len, cy,
        {color = ui.colors.accent_dim, width = 1})
    screen.draw_line(cx, cy - ring_r - ch_len, cx, cy - ring_r + 8,
        {color = ui.colors.accent_dim, width = 1})
    screen.draw_line(cx, cy + ring_r - 8, cx, cy + ring_r + ch_len,
        {color = ui.colors.accent_dim, width = 1})

    -- Title
    local title = "WORLD PULSE"
    local tw = screen.get_text_width(title, 24, true)
    screen.draw_text(title, (W - tw) / 2, cy - 14, {
        color = ui.colors.accent, size = 24, bold = true,
    })

    -- Subtitle
    local sub = "GLOBAL INTELLIGENCE MONITOR"
    local sw = screen.get_text_width(sub, 10, false)
    screen.draw_text(sub, (W - sw) / 2, cy + 16, {color = ui.colors.text_dim, size = 10})

    -- Version
    local ver = "v0.1.0"
    local vw = screen.get_text_width(ver, 9, false)
    screen.draw_text(ver, (W - vw) / 2, cy + 32, {color = ui.colors.accent_dim, size = 9})

    -- Source initialization list
    local sy = cy + 80
    screen.draw_text("INITIALIZING SYSTEMS", cx - 70, sy, {
        color = ui.colors.text_dim, size = 10, bold = true,
    })
    sy = sy + 20

    for _, src in ipairs(state.boot_sources) do
        local status_color = src.status == "OK" and ui.colors.green or ui.colors.text_dim
        local status_text = src.status == "OK" and "OK" or ".."

        screen.draw_text(src.name, cx - 120, sy, {color = ui.colors.text_dim, size = 11})
        screen.draw_text("[" .. status_text .. "]", cx + 100, sy, {
            color = status_color, size = 11, bold = src.status == "OK",
        })
        sy = sy + 18
    end

    -- Progress bar
    local prog = math.min(1, state.boot_time / 2.5)
    screen.draw_progress_bar(cx - 120, sy + 10, 240, 4, prog, {
        fill_color = ui.colors.accent,
        bg_color = ui.colors.panel,
        radius = 2,
    })

    -- Skip hint
    local skip = "Press any button to skip"
    local skw = screen.get_text_width(skip, 9, false)
    screen.draw_text(skip, (W - skw) / 2, H - 40, {color = ui.colors.text_dim, size = 9})
end

-- ── Main render ────────────────────────────────────────────────────────────

function on_render()
    screen.clear(ui.colors.bg[1], ui.colors.bg[2], ui.colors.bg[3])

    if state.screen == "boot" then
        draw_boot()
        return
    end

    -- Header with tabs
    ui.draw_header("WORLD PULSE", TABS, state.tab)

    -- Screen content
    if state.screen == "map" then
        map_screen.draw(state)
    elseif state.screen == "feed" then
        feed_screen.draw(state)
    elseif state.screen == "stats" then
        stats_screen.draw(state)
    end

    -- Footer
    ui.draw_footer({
        {"L1", "Prev", theme.btn_l},
        {"R1", "Next", theme.btn_r},
        {"Y", "Refresh", theme.btn_y},
        {"\226\151\178\226\151\188", "Navigate"},
    })
end
