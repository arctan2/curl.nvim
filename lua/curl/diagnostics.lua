local M = {
	diagnostics_ns = vim.api.nvim_create_namespace('curl_diagnostics')
}

function M.set_custom_diagnostics()
    local bufnr = vim.api.nvim_get_current_buf()

    local diagnostics = {
        {
            lnum = 5,
            col = 10,
            severity = vim.diagnostic.severity.WARN,
            message = "This is a custom warning message",
            source = "MyCustomSource",
        },
        {
            lnum = 8,
            col = 0,
            severity = vim.diagnostic.severity.ERROR,
            message = "A critical custom error occurred here",
            source = "MyCustomSource",
        },
    }

    vim.diagnostic.set(M.diagnostics_ns, bufnr, diagnostics, {})
end

return M
