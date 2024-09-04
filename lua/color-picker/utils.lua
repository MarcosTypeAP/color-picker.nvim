local M = {}

M.COLOR_HEX_REGEX = '#(%x%x)(%x%x)(%x%x)(%x?%x?)'
M.COLOR_HEX_SHORT_REGEX = '#(%x)(%x)(%x)(%x?)'
M.COLOR_RGB_REGEX = 'rgb%( *(%d+) *, *(%d+) *, *(%d+) *%)'
M.COLOR_RGBA_REGEX = 'rgba%( *(%d+) *, *(%d+) *, *(%d+), *(%d+%.?%d*) *%)'

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

---@param float number
---@return string
function M.format_float(float)
    local str = string.format('%.3f', float)
    ---@type integer
    local cut
    for i = #str, 1, -1 do
        if string.sub(str, i, i) == '0' then
            cut = i
        elseif string.sub(str, i, i) == '.' then
            cut = i
            break
        else
            break
        end
    end

    if cut == nil then
        return str
    end
    return string.sub(str, 1, cut - 1)
end

---@param base integer
---@param cols integer
---@param col integer
---@param brightness number
---@return integer
function M.col2colorbyte(base, cols, col, brightness)
    local t = 255 / cols
    return math.floor(math.min(math.min(col * t + base, 255) * brightness, 255))
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
        sat = col / (cols - 2),
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
    local col = (cols - 2) * hsl.sat
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

---@param str string
---@param init integer
---@return string?
---@return integer? start
local function extract_hex(str, init)
    local found = false
    for i = init, init - 6, -1 do
        if string.sub(str, i, i) == '#' then
            init = i
            found = true
            break
        end
    end

    if not found then
        return
    end

    local start, end_ = string.find(str, M.COLOR_HEX_REGEX, init)
    if start == nil then
        start, end_ = string.find(str, M.COLOR_HEX_SHORT_REGEX, init)
        if start == nil then
            return
        end
    end
    return string.sub(str, start, end_), start
end

---@param str string
---@param init integer
---@return string?
---@return integer? start
local function extract_rgb(str, init)
    local found = false
    for i = init, 1, -1 do
        if string.sub(str, i, i + 3) == 'rgb(' then
            init = i
            found = true
            break
        end
    end

    if not found then
        return
    end

    local start, end_ = string.find(str, M.COLOR_RGB_REGEX, init)
    if start == nil then
        return
    end
    return string.sub(str, start, end_), start
end

---@param str string
---@param init integer
---@return string?
---@return integer? start
local function extract_rgba(str, init)
    local found = false
    for i = init, 1, -1 do
        if string.sub(str, i, i + 4) == 'rgba(' then
            init = i
            found = true
            break
        end
    end

    if not found then
        return
    end

    local start, end_ = string.find(str, M.COLOR_RGBA_REGEX, init)
    if start == nil then
        return
    end
    return string.sub(str, start, end_), start
end

---@param rgb ColorRGB|ColorRGBA
local function validate_rgb(rgb)
    for i = 1, 3, 1 do
        if rgb[i] > 255 then
            error(string.format('Invalid RGB string: n=%d %d > 255', i, rgb[i]))
        end
    end
    if rgb[4] ~= nil and rgb[4] > 1 then
        error(string.format('Invalid RGBA string: n=4 %d > 1', rgb[4]))
    end
end

---@param str string
---@param init? integer
---@return ColorRGBA?
---@return string?
---@return ColorFormat?
---@return integer?
function M.extract_color(str, init)
    init = init or 1

    local hex, start = extract_hex(str, init)
    if hex ~= nil then
        local rgba = M.parse_hex(hex)
        return rgba, hex, 'hex', start
    end

    local rgb, start_ = extract_rgb(str, init)
    if rgb ~= nil then
        local rgba = M.parse_rgb(rgb)
        return rgba, rgb, 'rgb', start_
    end

    local rgba, start__ = extract_rgba(str, init)
    if rgba ~= nil then
        local rgba_ = M.parse_rgba(rgba)
        return rgba_, rgba, 'rgba', start__
    end
end

---@param str string
---@return ColorRGBA
function M.parse_hex(str)
    local r, g, b, a = string.match(str, M.COLOR_HEX_REGEX)
    if r == nil then
        ---@type string, string, string, string
        r, g, b, a = string.match(str, M.COLOR_HEX_SHORT_REGEX)
        r = r .. r
        g = g .. g
        b = b .. b
        a = a .. a
    end

    ---@type ColorRGBA
    local rgba = {
        tonumber(r, 16),
        tonumber(g, 16),
        tonumber(b, 16),
        (tonumber(a, 16) or 255) / 255
    }
    validate_rgb(rgba)
    return rgba
end

---@param str string
---@return ColorRGBA
function M.parse_rgb(str)
    local r, g, b = string.match(str, M.COLOR_RGB_REGEX)

    ---@type ColorRGBA
    local rgba = {
        tonumber(r),
        tonumber(g),
        tonumber(b),
        1,
    }
    validate_rgb(rgba)
    return rgba
end

---@param str string
---@return ColorRGBA
function M.parse_rgba(str)
    local r, g, b, a = string.match(str, M.COLOR_RGBA_REGEX)

    ---@type ColorRGBA
    local rgba = {
        tonumber(r),
        tonumber(g),
        tonumber(b),
        tonumber(a),
    }
    validate_rgb(rgba)
    return rgba
end

return M
