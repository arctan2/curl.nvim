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

---@param str string
---@return string[]
function M.split_lines(str)
    str = str:gsub("\r\n", "\n")

    if str:sub(-1) ~= "\n" then
        str = str .. "\n"
    end

    local result = {}
    for line in string.gmatch(str, "(.-)\n") do
        table.insert(result, line)
    end
    return result
end

---@param str string
---@param delim string
---@return string[]
function M.split_delim(str, delim)
    if delim == nil or #delim == 0 then
        return {str}
    end

    local result = {}
    local pos = 1
    local del_len = #delim

    while true do
        local nextPos = string.find(str, delim, pos, true)
        if nextPos then
            local part = string.sub(str, pos, nextPos - 1)
            pos = nextPos + del_len
            table.insert(result, part)
        else
            local part = string.sub(str, pos)
            table.insert(result, part)
            break
        end
    end

    return result
end

return M
