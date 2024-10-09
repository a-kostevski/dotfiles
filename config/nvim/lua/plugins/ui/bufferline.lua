return {
    'akinsho/bufferline.nvim',
    event = { 'VeryLazy' },
    dependencies = 'nvim-tree/nvim-web-devicons',
    -- TODO: Extend keys
    keys = {
        { '<leader>bb', '<cmd>BufferLinePick<cr>', desc = 'Select buffer' },
    },
    opts = {
        options = {
            mode = 'buffers',
            diagnostics = { 'nvim_lsp' },
            offsets = {
                {
                    filetype = 'neo-tree',
                    text = 'File Explorer',
                },
            },
            hover = {
                enabled = true,
                delay = 150,
                reveal = { 'close' },
            },
            diagnostics_indicator = function(count, level, diagnostics_dict, context)
                local icon = level:match("error") and " " or " "
                return " " .. icon .. count
            end
        },

    },
}
