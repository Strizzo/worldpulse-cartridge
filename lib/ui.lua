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
    blue      = {80, 140, 255},
    -- Tone/sentiment colors
    tone_neg  = {255, 70, 60},    -- negative news (conflict, crisis)
    tone_neu  = {255, 200, 50},   -- neutral
    tone_pos  = {0, 200, 100},    -- positive news
}

--- Get color for a GDELT tone value
function M.tone_color(tone)
    if tone < -3 then return M.colors.tone_neg end
    if tone > 3 then return M.colors.tone_pos end
    return M.colors.tone_neu
end

--- Tone label
function M.tone_label(tone)
    if tone < -5 then return "CRITICAL" end
    if tone < -3 then return "NEGATIVE" end
    if tone > 5 then return "VERY POSITIVE" end
    if tone > 3 then return "POSITIVE" end
    return "NEUTRAL"
end

--- Draw the top header bar
function M.draw_header(title, tabs, active_tab)
    local W = 720
    screen.draw_gradient_rect(0, 0, W, 36, 15, 25, 35, 10, 15, 20)
    screen.draw_line(0, 36, W, 36, {color = M.colors.accent_dim, width = 1})

    screen.draw_text(title, 12, 8, {color = M.colors.accent, size = 14, bold = true})

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
        return y + 18
    end
    return y + 4
end

--- Draw a status indicator dot
function M.draw_dot(x, y, r, color)
    screen.draw_circle(x, y, r, color[1], color[2], color[3])
end

--- Format GDELT date (20260315T120000Z) to readable
function M.format_date(gdelt_date)
    if not gdelt_date or #gdelt_date < 8 then return "" end
    local h = gdelt_date:sub(10, 11) or "00"
    local m = gdelt_date:sub(12, 13) or "00"
    return h .. ":" .. m .. " UTC"
end

--- Truncate domain for display
function M.short_domain(domain)
    if not domain then return "" end
    -- Remove www. prefix
    domain = domain:gsub("^www%.", "")
    -- Truncate if too long
    if #domain > 25 then
        return domain:sub(1, 22) .. "..."
    end
    return domain
end

return M
