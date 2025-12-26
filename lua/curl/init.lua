local M = {}
local reloader = require("plenary.reload")
local normal = require("curl.normal")
local insert = require("curl.insert")
local common = require("curl.common")
local parser = require("curl.parser")
local bufprint = require("curl.bufprint").bufprint

local function handle_input(bufnr)
	normal.handle_input(bufnr)
	insert.handle_input(bufnr)
end

local function reload()
	reloader.reload_module("curl")
	normal = require("curl.normal")
	insert = require("curl.insert")
	common = require("curl.common")
	parser = require("curl.parser")
	bufprint = require("curl.bufprint").bufprint
end

local function reset_custom_buffer(name)
    local bufnr = vim.fn.bufnr(name)

    if bufnr ~= -1 and vim.api.nvim_buf_is_valid(bufnr) then
        vim.api.nvim_buf_delete(bufnr, { force = true })
    end

    local new_buf = vim.api.nvim_create_buf(true, true)
    vim.api.nvim_buf_set_name(new_buf, name)
    return new_buf
end

function M.new_empty_buf()
	reload()

	local bufname = "-- CURL --"
	local bufnr = reset_custom_buffer(bufname)

    local lines = {
        "#REQ",
        "GET localhost",
        "Content-Type: text/html",
		'{ "cool": "body" }',
        "#END"
    }

    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
    vim.api.nvim_set_current_buf(bufnr)
    vim.api.nvim_win_set_cursor(0, {2, 0})
    vim.api.nvim_buf_set_option(bufnr, 'filetype', 'CURL')
	handle_input(bufnr);
end

function M.try_run_req()
	local bufnr = vim.api.nvim_get_current_buf()
	local start_line_nr, end_line_nr = common.get_block_bounds()
	local start_line = vim.api.nvim_buf_get_lines(bufnr, start_line_nr - 1, start_line_nr, false)[1]
	local end_line = vim.api.nvim_buf_get_lines(bufnr, end_line_nr - 1, end_line_nr, false)[1]

	if string.find(start_line, common.start_expr) == nil then
		error("No #REQ found in the whole file")
	end

	if string.find(end_line, common.end_expr) == nil then
		error("No #END found in the whole file")
	end

	local lines = vim.api.nvim_buf_get_lines(bufnr, start_line_nr - 1, end_line_nr, false)
	local res = parser.parse(lines)

	if res.error_msg then
		error(res.error_msg)
	else
		bufprint(res.cmd)
	end
end

-- vim.api.nvim_create_user_command('Curl', M.new_empty_buf, {})
vim.api.nvim_create_user_command('CurlTryRun', M.try_run_req, {})

return M
