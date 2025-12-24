local M = {}
local common = require("curl.common")
local parser = require("curl.parser")

local function is_on_last_word(cur_col)
    local line = tostring(vim.api.nvim_get_current_line())
    local last_word_start, _ = string.find(line, "(%S+)(%s*)$")

    if not last_word_start then
        return false
    end

    local actual_last_word = string.match(line, "(%S+)(%s*)$")
    local actual_end = last_word_start + #actual_last_word - 1

    return cur_col >= (last_word_start - 1) and cur_col <= (actual_end - 1)
end

local function smart_move(dir)
	local cursor = vim.api.nvim_win_get_cursor(0)
	local cur_row = cursor[1]
	local cur_col = cursor[2]

	local is_up = (dir == 'k')
	local is_down = (dir == 'j')
	local is_forward = dir == 'l' or dir == 'w'
	local is_backward = dir == 'h' or dir == 'b'

	local target_row

	if is_forward or is_down then
		target_row = cur_row + 1
	else
		target_row = (cur_row - 1)
	end

	local is_bound_start = common.is_boundary_start(target_row)
	local is_bound_end = common.is_boundary_end(target_row)

	if is_up and is_bound_start then
		print("upper boundary reached")
		return
	end

	if is_down and is_bound_end then
		print("lower boundary reached")
		return
	end

	if is_backward and is_bound_start and (cur_col == 0) then
		print("upper boundary reached")
		return
	end

	if is_forward and is_bound_end and is_on_last_word(cur_col) then
		print("lower boundary reached")
		return
	end

	vim.cmd("normal! " .. dir)
end

local function safe_delete()
	local _, end_marker = common.get_block_bounds()
	local cur_line = vim.api.nvim_win_get_cursor(0)[1]

	local new_marker = math.min(vim.v.count + cur_line, end_marker - 1)
	local new_count = new_marker - cur_line + 1
	local is_end = common.is_boundary_end(cur_line + new_count)

	vim.cmd("normal!" .. " " .. new_count .. "dd")

	if is_end then
		vim.fn.append(cur_line - 1, "")
		vim.api.nvim_win_set_cursor(0, {cur_line, 0})
	end
end

local allowed_motions = {
	['j'] = 'j',
	['k'] = 'k',
	['<cr>'] = 'j',
	['<bs>'] = 'h',
	['<space>'] = 'l',
	['w'] = 'w',
	['b'] = 'b',
}

local forbidden_motions = {
	'{', '}', 'G', 'gg', '(', ')', 'e', 'E', 'W', 'B', 'dj', 'dk',
	-- disable visual mode for now
	'v', 'V', '<C-v>', 'gh', 'gH',
	-- end of visual mode disable
}

function M.handle_input(bufnr)
	local opts = { noremap = true, silent = true, buffer = bufnr }

	for key, dir in pairs(allowed_motions) do
		vim.keymap.set('n', key, function() smart_move(dir) end, opts)
	end

	for _, key in ipairs(forbidden_motions) do
		vim.keymap.set('n', key, common.noop, opts)
	end

	vim.keymap.set('n', 'dd', safe_delete, opts)

	vim.keymap.set('n', '<leader>r', function ()
		local start_idx, end_idx = common.get_block_bounds()
		local lines = vim.api.nvim_buf_get_lines(0, start_idx - 1, end_idx, false)
		parser.parse(lines)
	end, opts)
end

return M
