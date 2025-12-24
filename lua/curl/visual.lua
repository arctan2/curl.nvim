local M = {}
local common = require("curl.common")

local function smart_move_visual(direction)
	local curr_row = vim.api.nvim_win_get_cursor(0)[1]
	local target_row = (direction == 'j') and curr_row + 1 or curr_row - 1

	if direction == 'j' and common.is_boundary_end(target_row) then
        vim.cmd("normal! gv")
        return
	elseif direction == 'k' and common.is_boundary_start(target_row) then
        vim.cmd("normal! gv")
        return
	end
    vim.cmd("normal! gv" .. direction)
end

function M.handle_input(bufnr)
	local opts = { silent = true, buffer = bufnr, noremap = true }

	vim.keymap.set('v', 'j', function() smart_move_visual('j') end, opts)
	vim.keymap.set('v', 'k', function() smart_move_visual('k') end, opts)
	vim.keymap.set('v', 'd', common.noop, opts)
end

return M
