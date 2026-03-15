-- lib/ui.lua — Common UI components for World Pulse

local M = {}

-- Custom color palette (cyberpunk teal)
M.colors = {
    bg        = {10, 15, 20},
    panel     = {15, 22, 30},
    panel_b   = {20, 35, 45},
    accent    = {0, 230, 200},
    accent_dim= {0, 100, 85},
    text      = {200, 220, 230},
    text_dim  = {80, 100, 115},
    red       = {255, 70, 60},
    orange    = {255, 170, 0},
    yellow    = {255, 220, 50},
    green     = {0, 200, 100},
    mag_low   = {0, 200, 100},     -- M < 4
    mag_med   = {255, 200, 0},     -- M 4-5.5
    mag_high  = {255, 120, 0},     -- M 5.5-7
    mag_crit  = {255, 50, 50},     -- M 7+
}

function M.mag_color(mag)
    if mag >= 7 then return M.colors.mag_crit end
    if mag >= 5.5 then return M.colors.mag_high end
    if mag >= 4 then return M.colors.mag_med end
    return M.colors.mag_low
end

function M.mag_label(mag)
    if mag >= 7 then return "CRITICAL" end
    if mag >= 5.5 then return "STRONG" end
    if mag >= 4 then return "MODERATE" end
    return "MINOR"
end

--- Draw the top header bar
function M.draw_header(title, tabs, active_tab)
    local W = 720
    -- Gradient header background
    screen.draw_gradient_rect(0, 0, W, 36, 15, 25, 35, 10, 15, 20)
    screen.draw_line(0, 36, W, 36, {color = M.colors.accent_dim, width = 1})

    -- Title
    screen.draw_text(title, 12, 8, {color = M.colors.accent, size = 14, bold = true})

    -- Tabs
    if tabs and #tabs > 0 then
        local tx = 160
        for i, tab in ipairs(tabs) do
            local tw = screen.get_text_width(tab, 11, i == active_tab)
            local c = i == active_tab and M.colors.accent or M.colors.text_dim
            if i == active_tab then
                screen.draw_rect(tx - 4, 24, tw + 8, 12, {color = M.colors.accent_dim, filled = true, radius = 3})
            end
            screen.draw_text(tab, tx, 10, {color = c, size = 11, bold = i == active_tab})
            tx = tx + tw + 20
        end
    end

    -- Timestamp
    local ts = os.date("%H:%M:%S")
    local tsw = screen.get_text_width(ts, 10, false)
    screen.draw_text(ts, W - tsw - 10, 12, {color = M.colors.text_dim, size = 10})
end

--- Draw footer hint bar
function M.draw_footer(hints)
    local W, H = 720, 720
    local fy = H - 28
    screen.draw_gradient_rect(0, fy, W, 28, 10, 15, 20, 15, 22, 30)
    screen.draw_line(0, fy, W, fy, {color = M.colors.accent_dim, width = 1})

    local x = 12
    for _, hint in ipairs(hints) do
        local label, action, color = hint[1], hint[2], hint[3] or M.colors.accent
        local w = screen.draw_button_hint(label, action, x, fy + 6, {color = color, size = 10})
        x = x + w + 14
    end
end

--- Draw a panel with title
function M.draw_panel(x, y, w, h, title, opts)
    opts = opts or {}
    local bg = opts.bg or M.colors.panel
    local border = opts.border or M.colors.accent_dim
    screen.draw_card(x, y, w, h, {bg = bg, border = border, radius = 4, shadow = false})
    if title then
        screen.draw_text(title, x + 8, y + 4, {color = M.colors.accent, size = 9, bold = true})
        return y + 18 -- content start y
    end
    return y + 4
end

--- Draw a status indicator dot
function M.draw_dot(x, y, r, color)
    screen.draw_circle(x, y, r, color[1], color[2], color[3])
end

--- Time ago string
function M.time_ago(timestamp_ms)
    local now = os.time() * 1000
    local diff = now - timestamp_ms
    local secs = math.floor(diff / 1000)
    if secs < 60 then return secs .. "s ago" end
    local mins = math.floor(secs / 60)
    if mins < 60 then return mins .. "m ago" end
    local hours = math.floor(mins / 60)
    if hours < 24 then return hours .. "h ago" end
    return math.floor(hours / 24) .. "d ago"
end

return M
