return {
    'folke/which-key.nvim',
    event = 'VimEnter',
    opts = {
        icons = {
            mappings = true,
        },
        timeoutlen = 500,
        spec = {
            { '<leader>b', group = 'Buffer' },
            { '<leader>d', group = 'Document' },
            { '<leader>f', group = 'Find/file' },
            { '<leader>r', group = 'Rename' },
            { '<leader>s', group = 'Search' },
            { '<leader>t', group = 'Toggle' },
            { '<leader>h', group = 'Git [H]unk', mode = { 'n', 'v' } },
            {
                "<leader>?",
                function()
                    require("which-key").show({ global = false })
                end,
                desc = "Buffer Local Keymaps (which-key)",
            },
        }
    },
}
