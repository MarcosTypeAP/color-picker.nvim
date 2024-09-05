local M = {}

local hex_digits = { '0', '1', '2', '3', '4', '5', '6', '7', '8', '9', 'A', 'B', 'C', 'D', 'E', 'F' }

---this is faster than string.format('%02X', n)
---(didn't remember string.format was a thing)
---@param n integer
---@return string
function M.byte2hex(n)
    if n < 0 or n > 255 then
        error('number out of range (0-255)')
    end
    return hex_digits[math.floor(n / 16) + 1] .. hex_digits[math.floor(n % 16) + 1]
end

---@param hsl ColorHSL
---@return ColorRGB
function M.hsl2rgb(hsl)
    local hue_rgb = M.hue2rgb(hsl.hue)

    local max = hsl.lum
    local min = max - (max * hsl.sat)

    ---@type ColorRGB
    return {
        math.floor(255 * (hue_rgb[1] * hsl.lum * hsl.sat + min)),
        math.floor(255 * (hue_rgb[2] * hsl.lum * hsl.sat + min)),
        math.floor(255 * (hue_rgb[3] * hsl.lum * hsl.sat + min)),
    }
end

---@param rgb ColorRGB
---@return ColorHSL
function M.rgb2hsl(rgb)
    local scaled = {
        rgb[1] / 255,
        rgb[2] / 255,
        rgb[3] / 255,
    }

    local max = math.max(unpack(scaled))
    local min = math.min(unpack(scaled))

    local lum = max
    local sat = (max - min) / lum
    if lum == 0 then
        sat = 0
    end

    local normalized = {
        ((scaled[1] - min) / sat) / lum,
        ((scaled[2] - min) / sat) / lum,
        ((scaled[3] - min) / sat) / lum,
    }
    if sat == 0 then
        normalized = { 1, 1, 1 }
    end

    ---@type number, number, number
    local R, G, B = unpack(normalized)
    local norm_max = math.max(unpack(normalized))

    local hue = -1

    if norm_max == R then
        hue = 0 + 60 * (G - B)
    elseif norm_max == G then
        hue = 120 + 60 * (B - R)
    elseif norm_max == B then
        hue = 240 + 60 * (R - G)
    end

    if hue == -1 then
        error('not reached')
    end

    ---@type ColorHSL
    return {
        lum = lum,
        sat = sat,
        hue = hue,
    }
end

---@param rows integer
---@param cols integer
---@param hue number
---@param row integer
---@param col integer
---@return ColorRGB
function M.pos2rgb(rows, cols, hue, row, col)
    ---@type ColorHSL
    local hsl = {
        lum = 1 - (row - 1) / (rows - 1),
        sat = col / (cols - 1),
        hue = hue
    }
    return M.hsl2rgb(hsl)
end

---@param rows integer
---@param cols integer
---@param rgb ColorRGB
---@return [integer, integer]
function M.rgb2pos(rows, cols, rgb)
    local hsl = M.rgb2hsl(rgb)
    local row = (rows - 1) * (1 - hsl.lum) + 1
    local col = (cols - 1) * hsl.sat
    return {
        math.floor(row),
        math.floor(col),
    }
end

---@param hue number
---@return ColorNormRGB
function M.hue2rgb(hue)
    hue = hue % 360

    if hue >= 0 and hue < 60 then
        return {
            1,
            hue / 60,
            0,
        }
    elseif hue >= 60 and hue < 120 then
        hue = hue - 60
        return {
            1 - hue / 60,
            1,
            0,
        }
    elseif hue >= 120 and hue < 180 then
        hue = hue - 120
        return {
            0,
            1,
            hue / 60,
        }
    elseif hue >= 180 and hue < 240 then
        hue = hue - 180
        return {
            0,
            1 - hue / 60,
            1,
        }
    elseif hue >= 240 and hue < 300 then
        hue = hue - 240
        return {
            hue / 60,
            0,
            1,
        }
    elseif hue >= 300 and hue < 360 then
        hue = hue - 300
        return {
            1,
            0,
            1 - hue / 60,
        }
    end

    error('not reached')
end

return M
