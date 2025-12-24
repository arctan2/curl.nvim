local M = {}
local scratch = require("scratch")

function M.fprint(...)
	local args = {...}

	for i, arg in ipairs(args) do
		args[i] = vim.inspect(arg)
	end

	if M.bufnr == nil then
		M.bufnr = scratch.new_hsplit({ args = args, type = "text", mode = "append" })
		return
	end

	M.bufnr = scratch.new_hsplit({ args = args, type = "text", mode = "append" }, M.bufnr)
end

return M
