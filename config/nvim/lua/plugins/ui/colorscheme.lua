return {
    'catppuccin/nvim',
    name = 'catppuccin',
    priority = 1000,
    opts = {
        integrations = {
            aerial = true,
            cmp = true,
            gitsigns = true,
            indent_blankline = true,
            mason = true,
            neotree = true,
            telescope = { enabled = true },
            treesitter = true,
            which_key = true,
        },
    },
    init = function()
        vim.cmd.colorscheme('catppuccin')
    end,
}
