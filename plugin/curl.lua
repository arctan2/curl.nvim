local curl = require("curl")

vim.api.nvim_create_user_command('CurlScratch', curl.new_empty_buf, { nargs = "*" })
vim.api.nvim_create_user_command('Curl', curl.try_run_req_within_buf, {})
vim.api.nvim_create_user_command('CurlNew', curl.new_req, {})

