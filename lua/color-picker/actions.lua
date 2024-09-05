local M = {}

---@param picker ColorPicker
function M.move_up(picker)
    if not picker:is_open() then
        return
    end
    local pos = vim.api.nvim_win_get_cursor(picker.win)
    local row = pos[1]

    local count = math.max(1, vim.v.count)

    row = picker:calc_next_row(row, -1 * count)

    vim.api.nvim_win_set_cursor(picker.win, { row, pos[2] })

    picker:update_buf(false)
end

---@param picker ColorPicker
function M.move_down(picker)
    if not picker:is_open() then
        return
    end
    local pos = vim.api.nvim_win_get_cursor(picker.win)
    local row = pos[1]

    local count = math.max(1, vim.v.count)

    row = picker:calc_next_row(row, 1 * count)

    vim.api.nvim_win_set_cursor(picker.win, { row, pos[2] })

    picker:update_buf(false)
end

---@param picker ColorPicker
function M.move_left(picker)
    if not picker:is_open() then
        return
    end
    local pos = vim.api.nvim_win_get_cursor(picker.win)
    local col = pos[2]

    local count = math.max(1, vim.v.count)
    col = picker:calc_next_col(col, -1 * count)

    vim.api.nvim_win_set_cursor(picker.win, { pos[1], col })
    picker:update_buf(false)
end

---@param picker ColorPicker
function M.move_right(picker)
    if not picker:is_open() then
        return
    end
    local pos = vim.api.nvim_win_get_cursor(picker.win)
    local col = pos[2]

    local count = math.max(1, vim.v.count)
    col = picker:calc_next_col(col, 1 * count)

    vim.api.nvim_win_set_cursor(picker.win, { pos[1], col })
    picker:update_buf(false)
end

---@param picker ColorPicker
function M.jump_up(picker)
    if not picker:is_open() then
        return
    end
    local pos = vim.api.nvim_win_get_cursor(picker.win)
    local row = pos[1]

    if pos[1] > picker.palette_height then
        return
    end

    local count = math.max(1, vim.v.count)

    local jump = picker:get_jump_len_v()
    row = picker:calc_next_row(row, -jump * count)

    vim.api.nvim_win_set_cursor(picker.win, { row, pos[2] })
    picker:update_buf(false)
end

---@param picker ColorPicker
function M.jump_down(picker)
    if not picker:is_open() then
        return
    end
    local pos = vim.api.nvim_win_get_cursor(picker.win)
    local row = pos[1]

    if pos[1] > picker.palette_height then
        return
    end

    local count = math.max(1, vim.v.count)

    local jump = picker:get_jump_len_v()
    row = picker:calc_next_row(row, jump * count)

    if row > picker.palette_height then
        row = picker.palette_height
    end

    vim.api.nvim_win_set_cursor(picker.win, { row, pos[2] })
    picker:update_buf(false)
end

---@param picker ColorPicker
function M.jump_left(picker)
    if not picker:is_open() then
        return
    end
    local pos = vim.api.nvim_win_get_cursor(picker.win)
    local col = pos[2]

    if pos[1] > picker.palette_height then
        return
    end

    local count = math.max(1, vim.v.count)

    local jump = picker:get_jump_len_h()
    col = picker:calc_next_col(col, -jump * count)

    vim.api.nvim_win_set_cursor(picker.win, { pos[1], col })
    picker:update_buf(false)
end

---@param picker ColorPicker
function M.jump_right(picker)
    if not picker:is_open() then
        return
    end
    local pos = vim.api.nvim_win_get_cursor(picker.win)
    local col = pos[2]

    if pos[1] > picker.palette_height then
        return
    end

    local count = math.max(1, vim.v.count)

    local jump = picker:get_jump_len_h()
    col = picker:calc_next_col(col, jump * count)

    vim.api.nvim_win_set_cursor(picker.win, { pos[1], col })
    picker:update_buf(false)
end

---@param picker ColorPicker
function M.hue_left(picker)
    if not picker:is_open() then
        return
    end
    local hue_step = picker:get_hue_step()
    local count = math.max(1, vim.v.count)
    picker.hue = (picker.hue - hue_step * count) % 360
    picker:update_buf(true)
end

---@param picker ColorPicker
function M.hue_right(picker)
    if not picker:is_open() then
        return
    end
    local hue_step = picker:get_hue_step()
    local count = math.max(1, vim.v.count)
    picker.hue = (picker.hue + hue_step * count) % 360
    picker:update_buf(true)
end

---@param picker ColorPicker
function M.select(picker)
    if not picker:is_open() then
        return
    end
    local rgb = picker:get_curr_rgb()
    picker:close()
    picker:write_color(rgb, picker.replace_data)
end

---@param picker ColorPicker
function M.close(picker)
    if not picker:is_open() then
        return
    end
    picker:close()
end

return M
