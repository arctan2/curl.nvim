local M = {}
-- local reloader = require("plenary.reload")
local common = require("curl.common")
local parser = require("curl.parser")

-- local function reload()
-- 	reloader.reload_module("curl")
-- 	common = require("curl.common")
-- 	parser = require("curl.parser")
-- end

-- reload()

local boilerplate = {
	"#REQ",
	"GET http://localhost:3000",
	"Content-Type: application/json",
	"",
	"#ARGS",
	"",
	"#END"
}

local function curl_buf_name(nr)
	return string.format("-- CURL %d --", nr)
end

local function bind_keymaps(buf)
	vim.keymap.set("n", "<leader>jq", ":.!jq . --tab<CR>", { noremap = true, silent = true, buffer = buf })
	vim.keymap.set("v", "<leader>jq", ":!jq . --tab<CR>", { noremap = true, silent = true, buffer = buf })
	vim.keymap.set("n", "<leader>rr", M.try_run_req_within_buf, { noremap = true, buffer = buf })
	vim.keymap.set("n", "<leader>nr", function ()
		local last_line = vim.api.nvim_buf_line_count(0)
		vim.api.nvim_buf_set_lines(0, -1, -1, false, { "" })
		vim.api.nvim_win_set_cursor(0, {last_line + 1, 0})
		M.new_req()
	end, { noremap = true, buffer = buf })
end

local function new_custom_buffer(mode)
	local i = 1
	while true do
		local bufname = curl_buf_name(i)
		local bufnr = vim.fn.bufnr(bufname)
		if not vim.api.nvim_buf_is_valid(bufnr) then
			bufnr = vim.api.nvim_create_buf(true, true)
			if mode == "v" then
				vim.cmd('vertical sbuffer ' .. bufnr)
			elseif mode == "h" then
				vim.cmd('sbuffer ' .. bufnr)
			end

			vim.api.nvim_buf_set_name(bufnr, bufname)
			bind_keymaps(bufnr)
			return bufnr
		end
		i = i + 1
	end
end

function M.new_empty_buf(opts)
	local bufnr = new_custom_buffer(opts.args)

    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, boilerplate)
    vim.api.nvim_set_current_buf(bufnr)
    vim.api.nvim_win_set_cursor(0, {2, 0})
    vim.api.nvim_buf_set_option(bufnr, 'filetype', 'curl')
end

---@param lines string[]
---@return number?
local function find_RES_in_lines(lines)
	for idx, line in ipairs(lines) do
		if string.find(line, "^#RES") then
			return idx
		end
	end
	return nil
end

local discard_starts_with = { "^ ", "^[*]", "^Note", "^[0-9]", "^[{}]" }

local function run_curl_clean(cmd, bufnr, line_nr, replace_star_slash, verbose_all)
	print("Running curl...")
	local stdout_data = {}
	local stderr_data = {}

	vim.system(cmd, {
		stdout = function(_, data)
			if data == nil then return end
			table.insert(stdout_data, data)
		end,
		stderr = function(_, data)
			if data == nil then return end
			table.insert(stderr_data, data)
		end,
	}, function(obj)
		vim.schedule(function()
			if not vim.api.nvim_buf_is_valid(bufnr) then return end

			local stdout_str = table.concat(stdout_data)
			local stderr_str = table.concat(stderr_data)

			if replace_star_slash then
				stderr_str = stderr_str:gsub("%*/", "* /")
				stdout_str = stdout_str:gsub("%*/", "* /")
			end

			local lines_stderr = vim.split(stderr_str, "[\r\n]", { trimempty = true })
			local lines_stdout = vim.split(stdout_str, "[\r\n]", { trimempty = true })

			if not verbose_all then
				lines_stderr = vim.tbl_filter(function(line)
					for _, v in pairs(discard_starts_with) do
						if string.find(line, v) then return false end
					end
					return line ~= ""
				end, lines_stderr)
			end

			local lines = lines_stderr
			table.insert(lines, "")
			for _, v in ipairs(lines_stdout) do
				table.insert(lines, v)
			end

			vim.api.nvim_buf_set_lines(bufnr, line_nr, line_nr, false, lines)
		end)

		print("curl finished with code "..obj.code)
	end)
end

function M.new_req()
	local bufnr = vim.api.nvim_get_current_buf()
	local cursor = vim.api.nvim_win_get_cursor(0)
	local line_nr = cursor[1]
    vim.api.nvim_buf_set_lines(bufnr, line_nr, line_nr, false, boilerplate)
	vim.api.nvim_win_set_cursor(0, {line_nr + 2, 0})
end

function M.try_run_req_within_buf()
	local bufnr = vim.api.nvim_get_current_buf()
	local start_line_nr, end_line_nr = common.get_block_bounds()
	local start_line = vim.api.nvim_buf_get_lines(bufnr, math.max(start_line_nr - 1, 0), start_line_nr, false)[1]
	local end_line = vim.api.nvim_buf_get_lines(bufnr, end_line_nr - 1, end_line_nr, false)[1]

	if start_line == nil or end_line == nil then
		error("Cursor not between any known REQ structure")
	end

	if string.find(start_line, common.start_expr) == nil then
		error("No #REQ found in the whole file")
	end

	if string.find(end_line, common.end_expr) == nil then
		error("No #END found in the whole file")
	end

	local lines = vim.api.nvim_buf_get_lines(bufnr, start_line_nr - 1, end_line_nr, false)

	local RES = find_RES_in_lines(lines)

	if RES then
		local start_idx = start_line_nr + RES - 1
		local diff = end_line_nr - start_idx
		vim.api.nvim_buf_set_lines(bufnr, start_idx, end_line_nr - 1, false, {""})
		vim.api.nvim_win_set_cursor(0, {start_idx, 0})
		end_line_nr = end_line_nr - diff + 1
	else
		vim.api.nvim_buf_set_lines(bufnr, end_line_nr - 1, end_line_nr - 1, false, {"#RES", ""})
		end_line_nr = end_line_nr + 1
	end

	local res = parser.parse(lines)

	if res.error_msg then
		error(res.error_msg)
	end

	run_curl_clean(
		res.cmd,
		bufnr,
		end_line_nr - 1,
		res.replace_star_slash,
		res.verbose_all
	)
end

return M
