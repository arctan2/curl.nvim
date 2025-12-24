local M = {}

local start_expr = "^#REQ.*"
local end_expr = "^#END.*"

M.start_expr = start_expr
M.end_expr = end_expr

function M.noop()
end

function M.is_boundary_start(line_num)
	local line_text = vim.fn.getline(line_num)
	return string.match(line_text, start_expr) ~= nil
end

function M.is_boundary_end(line_num)
	local line_text = vim.fn.getline(line_num)
	return string.match(line_text, end_expr) ~= nil
end

function M.get_block_bounds()
	local start_line = vim.fn.search(start_expr, "bnW")
	local end_line = vim.fn.search(end_expr, "nW")

	if end_line == 0 then end_line = vim.api.nvim_buf_line_count(0) + 1 end

	return start_line, end_line
end

function M.trim(s)
    local left_trimmed = string.gsub(s, "^%s+", "")
    return string.gsub(left_trimmed, "%s+$", "")
end

return M
