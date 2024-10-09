return {
    "hrsh7th/nvim-cmp",
    event = "InsertEnter",
    dependencies = {
        'hrsh7th/cmp-nvim-lsp',
        "hrsh7th/cmp-buffer",
        "hrsh7th/cmp-path",
        'onsails/lspkind.nvim',
        {
            "L3MON4D3/LuaSnip",
            version = "v4.*",
            build = "make install_jsregexp"
        },
        {
            "zbirenbaum/copilot-cmp",
            config = function()
                require("copilot_cmp").setup()
            end
        }

    },
    config = function()
        local cmp = require("cmp")

        local lspkind = require('lspkind')
        local luasnip = require("luasnip")
        local has_words_before = function()
            unpack = unpack or table.unpack
            local line, col = unpack(vim.api.nvim_win_get_cursor(0))
            return col ~= 0 and vim.api.nvim_buf_get_lines(0, line - 1, line, true)[1]:sub(col, col):match("%s") == nil
        end
        cmp.setup({
            formatting = {
                fields = { 'abbr', 'kind', 'menu' },
                expandable_indicator = true,
                format = lspkind.cmp_format({
                    mode = 'symbol_text',
                    maxwidth = 50,
                    menu = ({
                        nvim_lsp = "[LSP]",
                        luasnip = "[LuaSnip]",
                        path = "[Path]",
                        buffer = "[Buffer]",
                        copilot = "[Copilot]",
                    }),
                    show_labelDetails = true,
                })
            },
            snippet = {
                expand = function(args)
                    luasnip.lsp_expand(args.body)
                end
            },
            mapping = {
                ['<C-Space>'] = cmp.mapping.complete(),
                ['<CR>'] = cmp.mapping(function(fallback)
                    if cmp.visible() then
                        if luasnip.expandable() then
                            luasnip.expand()
                        else
                            cmp.confirm({
                                select = true,
                            })
                        end
                    else
                        fallback()
                    end
                end),

                ["<Tab>"] = cmp.mapping(function(fallback)
                    if cmp.visible() then
                        cmp.select_next_item()
                    elseif luasnip.locally_jumpable(1) then
                        luasnip.jump(1)
                    elseif has_words_before() then
                        cmp.complete()
                        if #cmp.get_entries() == 1 then
                            cmp.confirm({ select = true })
                        end
                    else
                        fallback()
                    end
                end, { "i", "s" }),

                ["<S-Tab>"] = cmp.mapping(function(fallback)
                    if cmp.visible() then
                        cmp.select_prev_item()
                    elseif luasnip.locally_jumpable(-1) then
                        luasnip.jump(-1)
                    else
                        fallback()
                    end
                end, { "i", "s" }),
            },
            sources = {
                { name = "copilot" },
                { name = "nvim_lsp", },
                { name = "path", },
                { name = "luasnip", },
                { name = "buffer", },
            }
        })
    end,
}
