local curl = require("curl")

vim.api.nvim_create_user_command('CurlScratch', curl.new_empty_buf, { nargs = "*" })
vim.api.nvim_create_user_command('CurlClearRes', curl.clear_response, {})
vim.api.nvim_create_user_command('CurlFold', curl.fold_block_under_cursor, {})
vim.api.nvim_create_user_command('CurlFoldAll', curl.fold_all_blocks, {})
vim.api.nvim_create_user_command('Curl', curl.try_run_req_within_buf, {})
vim.api.nvim_create_user_command('CurlNew', curl.new_req, {})

local curl_folds_group = vim.api.nvim_create_augroup("CurlFolds", { clear = true })

vim.api.nvim_create_autocmd({ "BufReadPost" }, {
	group = curl_folds_group,
	pattern = "*.curl",
	callback = function()
		vim.schedule(function()
			curl.fold_all_blocks()
		end)
	end,
})

vim.api.nvim_create_autocmd({ "BufRead", "BufNewFile" }, {
	pattern = "*.curl",
	callback = function()
		vim.bo.filetype = "curl"
	end,
})
