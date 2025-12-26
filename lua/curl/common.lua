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
	local cur_line = vim.api.nvim_get_current_line()
	local start_line = vim.fn.search(start_expr, "bnW")
	local end_line = vim.fn.search(end_expr, "nW")

	local cursor_pos = vim.api.nvim_win_get_cursor(0)
	local line_nr = cursor_pos[1]

	if cur_line and string.find(cur_line, "#REQ") then start_line = line_nr end

	if end_line == 0 then end_line = vim.api.nvim_buf_line_count(0) + 1 end

	return start_line, end_line
end

function M.trim(s)
    local left_trimmed = string.gsub(s, "^%s+", "")
    return string.gsub(left_trimmed, "%s+$", "")
end

---@param line string
---@param delim string
---@return [string?, string?]
function M.split_delim_once_trimmed(line, delim)
	local left = ""
	local i = line:find(delim, 1, true)

	if i == nil then
		return {nil, nil}
	end

	left = M.trim(line:sub(1, i - 1))
	line = M.trim(line:sub(i + 1, #line))

	return { left, line }
end

---@param t table
function M.table_insert_multi(t, ...)
	for _, v in ipairs({...}) do
		table.insert(t, v)
	end
end

---@param t table
---@return number
function M.table_size(t)
    local count = 0
    for _ in pairs(t) do
        count = count + 1
    end
    return count
end

return M
