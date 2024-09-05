local utils = require('color-picker.utils')
local conv = require('color-picker.conversions')
local actions = require('color-picker.actions')

local MIN_HEIGHT = 9 + 3
local MIN_WIDTH = 9 * 2

local COLOR_HEX_FORMAT = '#%02X%02X%02X'
local COLOR_HEX_ALPHA_FORMAT = '#%02X%02X%02X%02X'
local COLOR_RGB_FORMAT = 'rgb(%d, %d, %d)'
local COLOR_RGBA_FORMAT = 'rgba(%d, %d, %d, %s)'

local M = {}

---@alias ColorFormat 'hex'|'rgb'|'rgba'
local COLOR_FORMATS = { 'hex', 'rgb', 'rgba' }

---@alias PickerMappings table<string, fun(picker: ColorPicker)|nil>

---@class PickerDefaults
---@field height integer
---@field width integer
---@field jump_v integer
---@field jump_h integer
---@field hue_char string
---@field hue_step number
---@field format ColorFormat
---@field mappings PickerMappings

---@class PickerDefaultsPartial : PickerDefaults
---@field height? integer
---@field width? integer
---@field jump_v? integer
---@field jump_h? integer
---@field hue_char? string
---@field hue_step? number
---@field format? ColorFormat
---@field mappings? PickerMappings

---@type PickerDefaults
local DEFAULTS = {
    height = MIN_HEIGHT,
    width = MIN_WIDTH,
    jump_v = -1, -- sqrt(height)
    jump_h = -1, -- sqrt(width)
    hue_char = '|',
    hue_step = 10,
    format = 'hex',
    mappings = {
        ['k'] = actions.move_up,
        ['j'] = actions.move_down,
        ['h'] = actions.move_left,
        ['l'] = actions.move_right,
        ['K'] = actions.jump_up,
        ['J'] = actions.jump_down,
        ['H'] = actions.jump_left,
        ['L'] = actions.jump_right,
        ['<C-h>'] = actions.hue_left,
        ['<C-l>'] = actions.hue_right,
        ['<CR>'] = actions.select,
        ['q'] = actions.close,
    },
}

---@type PickerDefaults
local _user_defaults

---@param partial? PickerDefaultsPartial
---@return PickerDefaults
local function get_defaults(partial)
    partial = partial or {}
    local user_defaults = _user_defaults or {}

    ---@param key string
    ---@return any
    local function property(key)
        return partial[key] or user_defaults[key] or DEFAULTS[key]
    end

    ---@type PickerDefaults
    return {
        height = property('height'),
        width = property('width'),
        jump_v = property('jump_v'),
        jump_h = property('jump_h'),
        hue_step = property('hue_step'),
        hue_char = property('hue_char'),
        format = property('format'),
        mappings = property('mappings'),
    }
end

---@alias ColorRGB [integer, integer, integer]
---@alias ColorRGBA [integer, integer, integer, number]
---@alias ColorNormRGB [number, number, number]

---@class ColorHSL
---@field hue number
---@field sat number
---@field lum number

---@class ReplaceData
---@field pos [integer, integer]
---@field size integer
---@field format ColorFormat

---@class ColorPicker
---@field win integer
---@field buf integer
---@field height integer
---@field width integer
---@field palette_height integer
---@field hue number
---@field hue_char string
---@field hue_step number
---@field jump_v integer
---@field jump_h integer
---@field init_color ColorRGBA
---@field replace_data ReplaceData|nil
local Picker = {}

---@return boolean
function Picker:is_open()
    return self.win ~= nil and vim.api.nvim_win_is_valid(self.win)
end

function Picker:assert_open()
    if not self:is_open() then
        error('picker closed')
    end
end

---@param height integer
---@param width integer
function Picker:init(height, width)
    if height < MIN_HEIGHT or width < MIN_WIDTH then
        error(string.format('Invalid dimensions (min HxW = %dx%d)', MIN_HEIGHT, MIN_WIDTH))
    end

    self.height = height
    self.width = width
    self.palette_height = height - 3 -- hue, hex, and rgb lines

    self.buf = vim.api.nvim_create_buf(false, true)
    self:fill()
    self:set_keymaps()
end

---@param rgb ColorRGBA
---@param replace_data? ReplaceData
function Picker:open(rgb, replace_data)
    self.init_color = rgb
    self.replace_data = replace_data

    self.hue = conv.rgb2hsl(rgb).hue

    self.win = vim.api.nvim_open_win(self.buf, true, {
        relative = 'cursor',
        width = self.width,
        height = self.height,
        row = 1,
        col = 0,
        style = 'minimal',
        border = 'rounded',
        title = 'color picker',
        title_pos = 'center',
    })

    vim.api.nvim_win_set_cursor(self.win, self:get_pos_from_rgb(rgb))

    self:draw_text(rgb)
    self:colorize(true)
end

---@return string
function Picker:get_hue_char()
    if self.hue_char == nil then
        local defaults = get_defaults()
        self.hue_char = defaults.hue_char
    end
    return self.hue_char
end

---@param rgb ColorRGB
function Picker:draw_text(rgb)
    local hue_col = math.floor(((self.width) / 360) * self.hue)

    local color_hex = string.format(COLOR_HEX_FORMAT, unpack(rgb))
    local color_rgb = string.format(COLOR_RGB_FORMAT, unpack(rgb))

    vim.api.nvim_set_option_value('modifiable', true, { buf = self.buf })
    vim.api.nvim_buf_set_lines(self.buf, -4, -1, false, {
        string.rep(' ', hue_col) .. self:get_hue_char() .. string.rep(' ', self.width - hue_col),
        color_hex .. string.rep(' ', self.width - #color_hex),
        color_rgb .. string.rep(' ', self.width - #color_rgb),
    })
    vim.api.nvim_set_option_value('modifiable', false, { buf = self.buf })
end

---@param palette boolean
function Picker:colorize(palette)
    local hl_ns = vim.api.nvim_create_namespace('ColorPickerHighlight')
    vim.api.nvim_win_set_hl_ns(self.win, hl_ns)

    -- hue line
    local step = 360 / (self.width - 1)
    for col = 0, self.width - 1, 1 do
        local hue = step * col
        local hue_rgb = conv.hue2rgb(hue)
        ---@type ColorRGB
        local rgb = {
            255 * hue_rgb[1],
            255 * hue_rgb[2],
            255 * hue_rgb[3],
        }
        ---@type ColorRGB
        local inverted = {
            255 - rgb[1],
            255 - rgb[2],
            255 - rgb[3],
        }
        local group = string.format('a-%d', hue)
        vim.api.nvim_set_hl(hl_ns, group, {
            bg = string.format('#%02X%02X%02X', unpack(rgb)),
            fg = string.format('#%02X%02X%02X', unpack(inverted)),
            bold = true,
        })
        vim.api.nvim_buf_add_highlight(self.buf, hl_ns, group, self.palette_height, col, col + 1)
    end

    -- preview
    local curr_color = self:get_curr_rgb()
    vim.api.nvim_set_hl(hl_ns, 'preview-init',
        { bg = string.format('#%02X%02X%02X', unpack(self.init_color)) })
    vim.api.nvim_set_hl(hl_ns, 'preview-curr',
        { bg = string.format('#%02X%02X%02X', unpack(curr_color)) })
    local hex_size = 7
    local pad = 1 - self.width % 2
    local preview_size = (self.width - hex_size - pad) / 2
    -- #RRGGBB [CURR][INIT]
    vim.api.nvim_buf_add_highlight(self.buf, hl_ns, 'preview-curr', self.palette_height + 1,
        hex_size + pad, hex_size + pad + preview_size)
    vim.api.nvim_buf_add_highlight(self.buf, hl_ns, 'preview-init', self.palette_height + 1,
        hex_size + pad + preview_size, self.width)

    if not palette then
        return
    end

    -- palette
    for row = 1, self.palette_height, 1 do
        for col = 0, self.width - 1, 1 do
            local group = string.format('%d-%d', row, col)
            local rgb = self:get_rgb_from_pos(row, col)
            vim.api.nvim_set_hl(hl_ns, group, { bg = string.format('#%02X%02X%02X', unpack(rgb)) })
            vim.api.nvim_buf_add_highlight(self.buf, hl_ns, group, row - 1, col, col + 1)
        end
    end
end

---@return ColorRGB
function Picker:get_curr_rgb()
    local row, col = unpack(vim.api.nvim_win_get_cursor(self.win))
    return self:get_rgb_from_pos(row, col)
end

---@param row integer
---@param col integer
---@return ColorRGB
function Picker:get_rgb_from_pos(row, col)
    ---@type ColorHSL
    local hsl = {
        lum = 1 - (row - 1) / (self.palette_height - 1),
        sat = col / (self.width - 1),
        hue = self.hue
    }
    return conv.hsl2rgb(hsl)
end

---@param rgb ColorRGB
---@return [integer, integer]
function Picker:get_pos_from_rgb(rgb)
    local hsl = conv.rgb2hsl(rgb)
    local row = (self.palette_height - 1) * (1 - hsl.lum) + 1
    local col = (self.width - 1) * hsl.sat
    return {
        math.floor(row),
        math.floor(col),
    }
end

function Picker:fill()
    ---@type string[]
    local lines = {}
    for _ = 1, self.height, 1 do
        table.insert(lines, #lines + 1, string.rep(' ', self.width))
    end

    vim.api.nvim_set_option_value('modifiable', true, { buf = self.buf })
    vim.api.nvim_buf_set_lines(self.buf, 0, 0, false, lines)
    vim.api.nvim_buf_set_lines(self.buf, -2, -1, false, {}) -- remove last \n
    vim.api.nvim_set_option_value('modifiable', false, { buf = self.buf })
end

---@param col integer
---@param jump integer
---@return integer
function Picker:calc_next_col(col, jump)
    col = col + jump

    if col < 0 then
        col = 0
    end
    if col > self.width - 1 then
        col = self.width - 1
    end

    return col
end

---@param row integer
---@param jump integer
---@return integer
function Picker:calc_next_row(row, jump)
    row = row + jump

    if row < 1 then
        row = 1
    end
    if row > self.height then
        row = self.height
    end

    return row
end

---@return integer
function Picker:get_jump_len_v()
    if self.jump_v == nil then
        local defaults = get_defaults()

        self.jump_v = defaults.jump_v

        if self.jump_v == -1 then
            self.jump_v = math.floor(math.sqrt(self.palette_height))
        end
    end

    return self.jump_v
end

---@return integer
function Picker:get_jump_len_h()
    if self.jump_h == nil then
        local defaults = get_defaults()

        self.jump_h = defaults.jump_h

        if self.jump_h == -1 then
            self.jump_h = math.floor(math.sqrt(self.width * 2))
        end
    end

    return self.jump_h
end

---@return number
function Picker:get_hue_step()
    if self.hue_step == nil then
        local defaults = get_defaults()
        self.hue_step = defaults.hue_step
    end

    return self.hue_step
end

function Picker:set_keymaps()
    ---@type vim.keymap.set.Opts
    local opts = {
        buffer = self.buf,
        noremap = true,
        nowait = true,
        silent = true,
    }

    local defaults = get_defaults()

    for key, action in pairs(defaults.mappings) do
        if action ~= nil then
            vim.keymap.set('n', key, function()
                action(self)
            end, opts)
        end
    end

    for i = 0, 9, 1 do
        vim.keymap.set('n', string.format('g%d', i), function()
            self.hue = 36 * i
            self:update_buf(true)
        end, opts)
    end
end

---@param full_redraw boolean
function Picker:update_buf(full_redraw)
    local pos = vim.api.nvim_win_get_cursor(self.win)

    if pos[1] > self.palette_height then
        return
    end

    local rgb = self:get_curr_rgb()
    self:draw_text(rgb)
    self:colorize(full_redraw)
end

---@param rgb ColorRGB|ColorRGBA
---@param replace_data ReplaceData|nil
function Picker:write_color(rgb, replace_data)
    if self:is_open() then
        error('picker still open')
    end

    ---@type string
    local format
    if replace_data ~= nil then
        format = replace_data.format
    else
        local defaults = get_defaults()
        format = defaults.format
    end

    ---@type number|nil
    local alpha = rgb[4] or (self.init_color and self.init_color[4])

    ---@type string
    local color
    if format == 'hex' then
        if alpha < 1 then
            color = string.format(COLOR_HEX_ALPHA_FORMAT, rgb[1], rgb[2], rgb[3], math.floor(alpha * 255))
        else
            color = string.format(COLOR_HEX_FORMAT, unpack(rgb))
        end
    elseif format == 'rgb' then
        color = string.format(COLOR_RGB_FORMAT, unpack(rgb))
    elseif format == 'rgba' then
        color = string.format(COLOR_RGBA_FORMAT, rgb[1], rgb[2], rgb[3], utils.format_float(alpha or 1))
    else
        error('not reached')
    end

    if replace_data ~= nil then
        local row = replace_data.pos[1] - 1
        local col = replace_data.pos[2] - 1

        vim.api.nvim_buf_set_text(0,
            row, col,
            row, col + replace_data.size,
            { color })
    else
        local pos = vim.api.nvim_win_get_cursor(0)
        local row = pos[1] - 1
        local col = pos[2] + 1

        if #vim.api.nvim_get_current_line() == 0 then
            col = col - 1
        end

        vim.api.nvim_buf_set_text(0,
            row, col,
            row, col,
            { color })
    end
end

---@param force? boolean
function Picker:close(force)
    force = force or true

    self:assert_open()

    vim.api.nvim_win_close(self.win, force)
    vim.api.nvim_buf_delete(self.buf, { force = force })

    self.win = nil
end

---@class PickerOpts
---@field defaults? PickerDefaultsPartial

---@param opts PickerOpts
function M.setup(opts)
    _user_defaults = get_defaults(opts.defaults)

    vim.api.nvim_create_user_command('ColorPickerInsert', function(extra)
        M.insert({ color = extra.fargs[1] })
    end, { nargs = '?' })

    vim.api.nvim_create_user_command('ColorPickerReplace', function(extra)
        M.replace({ format = extra.fargs[1] })
    end, { nargs = '?' })

    vim.api.nvim_create_user_command('ColorPickerReformat', function(extra)
        M.reformat(extra.fargs[1])
    end, { nargs = 1 })
end

---@class OpenOpts
---@field color? string
---@field height? integer
---@field width? integer
---@field replace_data? ReplaceData

---@param opts? OpenOpts
function M.open(opts)
    opts = opts or {}

    local defaults = get_defaults({ height = opts.height, width = opts.width })
    local color = opts.color or '#FF0000'

    local rgba, _, _, _ = utils.extract_color(color)

    if rgba == nil then
        error(string.format('Invalid color: "%s"', color))
    end

    Picker:init(defaults.height, defaults.width)
    Picker:open(rgba, opts.replace_data)
end

---@class InsertOpts
---@field color? string
---@field height? integer
---@field width? integer

---@param opts? InsertOpts
function M.insert(opts)
    opts = opts or {}
    M.open({
        color = opts.color,
        height = opts.height,
        width = opts.width,
    })
end

---@class ReplaceOpts
---@field height? integer
---@field width? integer
---@field format? ColorFormat

---@param opts? ReplaceOpts
function M.replace(opts)
    opts = opts or {}

    local pos = vim.api.nvim_win_get_cursor(0)
    local line = vim.api.nvim_get_current_line()

    local _, color, format, start = utils.extract_color(line, pos[2] + 1)
    if color == nil or format == nil or start == nil then
        print('No valid color under the cursor')
        return
    end

    M.open({
        color = color,
        height = opts.height,
        width = opts.width,
        replace_data = {
            pos = { pos[1], start },
            size = #color,
            format = opts.format or format,
        }
    })
end

---@param format ColorFormat
function M.reformat(format)
    format = string.lower(format)
    local valid = false
    for _, f in pairs(COLOR_FORMATS) do
        if f == format then
            valid = true
            break
        end
    end
    if not valid then
        error('Invalid format. Supported formats: ' .. table.concat(COLOR_FORMATS, ', '))
    end

    local defaults = get_defaults()

    local pos = vim.api.nvim_win_get_cursor(0)
    local line = vim.api.nvim_get_current_line()

    local rgba, color, _, start = utils.extract_color(line, pos[2] + 1)
    if rgba == nil or color == nil or start == nil then
        print('No valid color under the cursor')
        return
    end

    Picker:init(defaults.height, defaults.width)
    Picker:write_color(rgba, {
        pos = { pos[1], start },
        size = #color,
        format = format,
    })
end

return M
