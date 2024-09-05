local conv = require('color-picker.conversions')

local ins = vim.inspect

---@param rgb1 ColorRGB
---@param rgb2 ColorRGB
---@return boolean
local function compare_rgb(rgb1, rgb2)
    for i = 1, 3, 1 do
        if rgb1[i] ~= rgb2[i] then
            return false
        end
    end
    return true
end

local function test_rgb_and_hsl_conversion_consistency()
    local rgb_in = { 160, 161, 195 }

    local hsl_1 = conv.rgb2hsl(rgb_in)

    local rgb_1 = conv.hsl2rgb(hsl_1)

    local hsl_2 = conv.rgb2hsl(rgb_1)

    local rgb_out = conv.hsl2rgb(hsl_2)

    if not compare_rgb(rgb_in, rgb_out) then
        print(ins(rgb_in), ins(rgb_out))
        error('failed')
    end
end

local function test_rgb_and_pos_conversion_consistency()
    local H, W = 20, 40
    local hue = 69

    local pos_in = { 4, 20 }

    local rgb_1 = conv.pos2rgb(H, W, hue, unpack(pos_in))

    local pos_1 = conv.rgb2pos(H, W, rgb_1)

    local rgb_2 = conv.pos2rgb(H, W, hue, unpack(pos_1))

    local pos_out = conv.rgb2pos(H, W, rgb_2)

    if pos_in[1] ~= pos_out[1] or pos_in[2] ~= pos_out[2] then
        print(ins(pos_in), ins(pos_out))
        error('failed')
    end
end

local function test_rgb_and_pos_conversion_edge_cases()
    local H, W = 20, 40

    ---@param row integer
    ---@param col integer
    ---@param expected ColorRGB
    local function assert_pos_rgb(row, col, expected)
        local rgb = conv.pos2rgb(H, W, 0, row, col)
        if not compare_rgb(rgb, expected) then
            print(ins(rgb), ins(expected))
            error('failed')
        end
    end

    assert_pos_rgb(1, 0, { 255, 255, 255 })
    assert_pos_rgb(1, 39, { 255, 0, 0 })
    assert_pos_rgb(20, 39, { 0, 0, 0 })
    assert_pos_rgb(20, 0, { 0, 0, 0 })

    ---@param rgb ColorRGB
    ---@param expected [integer, integer]
    local function assert_rgb_pos(rgb, expected)
        local pos = conv.rgb2pos(H, W, rgb)
        if pos[1] ~= expected[1] or pos[2] ~= expected[2] then
            print(ins(pos), ins(expected))
            error('failed')
        end
    end

    assert_rgb_pos({ 255, 255, 255 }, { 1, 0 })
    assert_rgb_pos({ 255, 0, 0 }, { 1, 39 })
    assert_rgb_pos({ 0, 0, 0 }, { 20, 0 })
end

test_rgb_and_hsl_conversion_consistency()
test_rgb_and_pos_conversion_consistency()
test_rgb_and_pos_conversion_edge_cases()
