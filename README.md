# color-picker.nvim
Neovim plugin for selecting, replacing and formatting colors via a (beautiful) color palette.

<img src="https://raw.githubusercontent.com/MarcosTypeAP/color-picker.nvim/images/images/img1.png" width="500">

### Features
- Insert, replace and reformat the color under the cursor.
- Customizable size color palette (color resolution).
- Full customizable keyboard navigation.
- Support for RGB, RGBA and HEX formatting.

### Instalation
Using [lazy.nvim](https://github.com/folke/lazy.nvim):
```lua
{ 'MarcosTypeAP/color-picker.nvim' }
```
Using [vim-plug](https://github.com/junegunn/vim-plug)
``` vim
Plug 'MarcosTypeAP/color-picker.nvim'
```
Using [packer.nvim](https://github.com/wbthomason/packer.nvim)
```lua
use { 'MarcosTypeAP/color-picker.nvim' }
```

### Commands
`:ColorPickerInsert`: Insert a new color at the cursor. Accepts an optional initial `color`.<br>
`:ColorPickerReplace`: Replace the color under the cursor with a new one. Accepts an optional `format`.<br>
`:colorPickerReformat`: Changes the format of the color under the cursor. Accpets `format`.

### Configuration
```lua
local picker = require('color-picker')
local actions = require('color-picker.actions')

picker.setup({
    defaults = {
        -- palette size (min 12x18)
        height = 12,
        width = 18,

        -- jump length
        jump_v = -1, -- -1 = sqrt(height)
        jump_h = -1, -- -1 = sqrt(width * 2)

        -- char used to indicate current hue
        hue_char = '|',

        -- hue step per rotation (in degrees)
        hue_step = 10,

        -- format used when inserting a new color
        format = 'hex',

        -- palette mappings
        mappings = {
            -- disable a mapping
            -- ['k'] = nil,

            -- move one cell
            ['k'] = actions.move_up,
            ['j'] = actions.move_down,
            ['h'] = actions.move_left,
            ['l'] = actions.move_right,

            -- move many cells
            ['K'] = actions.jump_up,
            ['J'] = actions.jump_down,
            ['H'] = actions.jump_left,
            ['L'] = actions.jump_right,

            -- rotate hue
            ['<C-h>'] = actions.hue_left,
            ['<C-l>'] = actions.hue_right,

            -- select the color under the cursor
            ['<CR>'] = actions.select,

            -- close the palette
            ['q'] = actions.close,
        },
    }
})

vim.keymap.set('n', '<C-c>i', picker.insert)
vim.keymap.set('n', '<C-c>r', picker.replace)
vim.keymap.set('n', '<C-c>f', picker.reformat)
-- also with options
vim.keymap.set('n', '<C-c>i', function() picker.insert({ width = 20 }) end)
```

### Some definitions
```lua
---@alias ColorRGB [integer, integer, integer]
---@alias ColorRGBA [integer, integer, integer, number]

---@alias ColorFormat 'hex'|'rgb'|'rgba'

---@alias PickerMappings table<string, fun(picker: ColorPicker)|nil>

---@class PickerDefaultsPartial : PickerDefaults
---@field height? integer
---@field width? integer
---@field jump_v? integer
---@field jump_h? integer
---@field hue_char? string
---@field hue_step? number
---@field format? ColorFormat
---@field mappings? PickerMappings

---@class PickerOpts
---@field defaults? PickerDefaultsPartial

---@class ReplaceData
---@field pos [integer, integer]
---@field size integer
---@field format ColorFormat

---@class OpenOpts
---@field color? string
---@field height? integer
---@field width? integer
---@field replace_data? ReplaceData

---@class InsertOpts
---@field color? string
---@field height? integer
---@field width? integer

---@class ReplaceOpts
---@field height? integer
---@field width? integer
---@field format? ColorFormat
```
