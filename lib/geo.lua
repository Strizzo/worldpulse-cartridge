-- lib/geo.lua — Map projection and coordinate helpers

local M = {}

-- Map image dimensions and position on screen
M.MAP_X = 0
M.MAP_Y = 38
M.MAP_W = 720
M.MAP_H = 360

--- Convert longitude/latitude to pixel coordinates on the map
-- @param lon number  longitude (-180 to 180)
-- @param lat number  latitude (-90 to 90)
-- @return number, number  x, y pixel coordinates
function M.to_pixel(lon, lat)
    local x = M.MAP_X + (lon + 180) / 360 * M.MAP_W
    local y = M.MAP_Y + (90 - lat) / 180 * M.MAP_H
    return x, y
end

--- Check if a pixel coordinate is within the map bounds
function M.in_bounds(x, y)
    return x >= M.MAP_X and x <= M.MAP_X + M.MAP_W
       and y >= M.MAP_Y and y <= M.MAP_Y + M.MAP_H
end

--- Draw the map background image
function M.draw_map()
    screen.draw_image("assets/map.png", M.MAP_X, M.MAP_Y, {w = M.MAP_W, h = M.MAP_H})
end

--- Draw a pulsing marker at a lat/lon
-- @param lon   number  longitude
-- @param lat   number  latitude
-- @param color table   {r, g, b}
-- @param size  number  base radius
-- @param pulse number  pulse phase (0 to 1, from animation timer)
function M.draw_marker(lon, lat, color, size, pulse)
    local x, y = M.to_pixel(lon, lat)
    if not M.in_bounds(x, y) then return end

    -- Outer pulse ring (fades out)
    if pulse then
        local ring_r = size + pulse * 6
        local alpha_factor = 1 - pulse
        local rc = {
            math.floor(color[1] * alpha_factor * 0.4),
            math.floor(color[2] * alpha_factor * 0.4),
            math.floor(color[3] * alpha_factor * 0.4),
        }
        screen.draw_circle(x, y, ring_r, rc[1], rc[2], rc[3])
    end

    -- Core dot
    screen.draw_circle(x, y, size, color[1], color[2], color[3])
end

--- Draw a line between two lat/lon points
function M.draw_arc(lon1, lat1, lon2, lat2, color)
    local x1, y1 = M.to_pixel(lon1, lat1)
    local x2, y2 = M.to_pixel(lon2, lat2)
    screen.draw_line(x1, y1, x2, y2, {color = color, width = 1})
end

return M
