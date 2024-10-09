return {
    {
        'stevearc/conform.nvim',
        lazy = true,
        dependencies = { 'mason.nvim' },
        event = { "BufReadPre", "BufNewFile" },
        cmd = { 'ConformInfo' },
        keys = {
            {
                '<leader>F',
                function()
                    require('conform').format({ async = true, })
                end,
                mode = '',
                desc = '[F]ormat buffer',
            },
        },
        config = function()
            local conform = require('conform')
            conform.setup({
                formaters_by_ft = {
                    bash = { 'shfmt', 'shellcheck' },
                    javascript = { 'prettierd', 'prettier', stop_on_first = true, },
                    lua = { 'stylua ' },
                    python = { 'isort', 'black' },
                    rust = { 'rustfmt' },
                    sh = { 'shfmt', 'shellcheck' },
                    zsh = { 'shfmt', 'shellcheck' },
                },
                default_format_opts = {
                    timeout_ms = 3000,
                    async = false,
                    quit = false,
                    lsp_format = "fallback",
                },
                -- Set up format-on-save
                format_on_save = { timeout_ms = 500, async = false, quit = false, lsp_format = "fallback" },

                -- Customize formatters
                --formatters = {
                --   shfmt = {
                --        prepend_args = { "-i", "2" },
                --  },
                -- },
            })
        end
    }
}
