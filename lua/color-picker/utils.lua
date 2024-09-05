local M = {}

M.COLOR_HEX_REGEX = '#(%x%x)(%x%x)(%x%x)(%x?%x?)'
M.COLOR_HEX_SHORT_REGEX = '#(%x)(%x)(%x)(%x?)'
M.COLOR_RGB_REGEX = 'rgb%( *(%d+) *, *(%d+) *, *(%d+) *%)'
M.COLOR_RGBA_REGEX = 'rgba%( *(%d+) *, *(%d+) *, *(%d+), *(%d+%.?%d*) *%)'

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
