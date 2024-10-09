-- https://github.com/nvim-telescope/telescope.nvim
return {
    'nvim-telescope/telescope.nvim',
    event = 'VimEnter',
    dependencies = {
        'nvim-lua/plenary.nvim',
        {
            'nvim-telescope/telescope-fzf-native.nvim',
            build = 'make',
        },
        { 'nvim-telescope/telescope-ui-select.nvim' },
        { 'nvim-tree/nvim-web-devicons' },
    },
    keys = {
        { '<leader>ff', '<cmd>Telescope find_files<cr>', desc = '[F]ind [F]ile' },
        { '<leader>fg', '<cmd>Telescope live_grep<cr>',  desc = '[F]ind in [P]roject' },
        { '<leader>fb', '<cmd>Telescope buffers<cr>',    desc = '[F]ind [B]uffer' },
        { '<leader>fh', '<cmd>Telescope help_tags<cr>',  desc = '[F]ind [H]elp tag' },
    },
    opts = {},
}
