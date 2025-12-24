local M = {}
local normal = require("curl.normal")
local insert = require("curl.insert")
local reloader = require("plenary.reload")

local function handle_input(bufnr)
	normal.handle_input(bufnr)
	insert.handle_input(bufnr)
end

local function reload()
	reloader.reload_module("curl")
	normal = require("curl.normal")
	insert = require("curl.insert")
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

vim.api.nvim_create_user_command('Curl', M.new_empty_buf, {})

return M
