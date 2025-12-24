local M = {}
local common = require("curl.common")

local function smart_move(dir)
	local curr_row = vim.api.nvim_win_get_cursor(0)[1]
	local is_forward = (dir == 'j' or dir == 'l' or dir == 'w')
	local is_backward = (dir == 'k' or dir == 'h' or dir == 'b')
	local target_row = is_forward and curr_row + 1 or curr_row - 1

	if is_forward and common.is_boundary_end(target_row) then
		print("lower boundary reached")
		return
	end

	if is_backward and common.is_boundary_start(target_row) then
		print("upper boundary reached")
		return
	end

	vim.cmd("normal! " .. dir)
end

local function safe_delete()
	local _, end_marker = common.get_block_bounds()
	local curr_line = vim.api.nvim_win_get_cursor(0)[1]

	local new_marker = math.min(vim.v.count + curr_line, end_marker - 1)
	local new_count = new_marker - curr_line + 1
	local is_end = common.is_boundary_end(curr_line + new_count)

	vim.cmd("normal!" .. " " .. new_count .. "dd")

	if is_end then
		vim.fn.append(curr_line - 1, "")
		vim.api.nvim_win_set_cursor(0, {curr_line, 0})
	end
end

local allowed_motions = {
	['<up>'] = 'k',
	['<down>'] = 'j',
	['<left>'] = 'h',
	['<right>'] = 'l',

	['<s-left>'] = 'h',
	['<s-right>'] = 'l',

	['<c-left>'] = 'h',
	['<c-right>'] = 'l',
}

local forbidden_motions = {
	'{', '}', 'G', 'gg', '(', ')', 'e', 'E', 'W', 'B', 'dj', 'dk', "<S-up>", "<S-down>",
	-- disable visual mode for now
	'v', 'V', '<C-v>', 'gh', 'gH',
	-- end of visual mode disable
}

function M.handle_input(bufnr)
	local opts = { noremap = true, silent = true, buffer = bufnr }

	for key, dir in pairs(allowed_motions) do
		vim.keymap.set('i', key, function() smart_move(dir) end, opts)
	end

	for _, key in ipairs(forbidden_motions) do
		vim.keymap.set('i', key, common.noop, opts)
	end
end

return M
