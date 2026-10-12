-- Equirectangular atlas projection using the existing map asset.
local U = _G.ui.public
local M = {MAP_X = 24, MAP_Y = 180, MAP_W = 672, MAP_H = 336}

function M.to_pixel(lon, lat)
    return M.MAP_X + (lon + 180) / 360 * M.MAP_W,
        M.MAP_Y + (90 - lat) / 180 * M.MAP_H
end

function M.in_bounds(x, y)
    return x >= M.MAP_X and x <= M.MAP_X + M.MAP_W
        and y >= M.MAP_Y and y <= M.MAP_Y + M.MAP_H
end

function M.draw_map()
    screen.draw_image("assets/map.png", M.MAP_X, M.MAP_Y, {w = M.MAP_W, h = M.MAP_H})
    U.rule(M.MAP_X, M.MAP_Y + M.MAP_H, M.MAP_W, U.C.line)
end

function M.draw_marker(lon, lat, color, size, selected)
    local x, y = M.to_pixel(lon, lat)
    if not M.in_bounds(x, y) then return end
    local diameter = size * 2
    if selected then
        U.rect(x - size - 5, y - size - 5, diameter + 10, diameter + 10, U.C.paper)
        U.rect(x - size - 3, y - size - 3, diameter + 6, diameter + 6, U.C.black)
    end
    U.rect(x - size, y - size, diameter, diameter, color)
end

return M
