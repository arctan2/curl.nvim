vim.filetype.add({
	extension = {
		curl = "curl",
	},
	pattern = {
		["%.curl_buffer$"] = "curl",
	},
})
