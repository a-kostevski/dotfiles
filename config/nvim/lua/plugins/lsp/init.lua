return {
    "neovim/nvim-lspconfig",
    cmd = { 'LspInfo', 'LspInstall', 'LspStart' },
    event = { "BufReadPre", "BufNewFile" },
    dependencies = {
        {
            'mason.nvim',
            { 'williamboman/mason-lspconfig.nvim', config = function() end },
        },
    },
    config = function()
        local lspconfig = require('lspconfig')

        vim.api.nvim_create_autocmd('LspAttach', {
            group = vim.api.nvim_create_augroup('lsp-attach', {
                clear = true
            }),
            callback = function(event)
                local map = function(keys, func, desc, mode)
                    mode = mode or 'n'
                    local opts = {
                        noremap = true,
                        silent = true,
                        buffer = event.buf,
                        desc = "LSP: " .. desc
                    }
                    vim.keymap.set(mode, keys, func, opts)
                end

                map('<leader>K', '<cmd>lua vim.lsp.buf.hover()<cr>', 'Hover info')
                map('<leader>gd', '<cmd>lua vim.lsp.buf.definition()<cr>', 'Goto Definition')
                map('<leader>gD', '<cmd>lua vim.lsp.buf.declaration()<cr>', 'Goto Declaration')
                map('<leader>gi', '<cmd>lua vim.lsp.buf.implementation()<cr>', 'Goto Implementation')
                map('<leader>go', '<cmd>lua vim.lsp.buf.type_definition()<cr>', 'Goto type definition')
                map('<leader>gr', '<cmd>lu  vim.lsp.buf.references()<cr>', 'Goto References')
                map('<leader>gs', '<cmd>lua vim.lsp.buf.signature_help()<cr>', 'Goto Signature')
                map('<leader>gr', '<cmd>lua vim.lsp.buf.rename()<cr>', 'Rename Symbol')
                map('<F3>', '<cmd>lua vim.lsp.buf.format({async = true})<cr>', 'Format', { 'n', 'x' })
                -- map('<leader><F4>', '<cmd>lua vim.lsp.buf.code_action()<cr>', opts)


                -- When you move your cursor, the highlights will be cleared (the second autocommand).
                local client = vim.lsp.get_client_by_id(event.data.client_id)
                if client and client.supports_method(vim.lsp.protocol.Methods.textDocument_documentHighlight) then
                    local highlight_augroup = vim.api.nvim_create_augroup('lsp-highlight', {
                        clear = false
                    })
                    vim.api.nvim_create_autocmd({ 'CursorHold', 'CursorHoldI' }, {
                        buffer = event.buf,
                        group = highlight_augroup,
                        callback = vim.lsp.buf.document_highlight
                    })

                    vim.api.nvim_create_autocmd({ 'CursorMoved', 'CursorMovedI' }, {
                        buffer = event.buf,
                        group = highlight_augroup,
                        callback = vim.lsp.buf.clear_references
                    })

                    vim.api.nvim_create_autocmd('LspDetach', {
                        group = vim.api.nvim_create_augroup('lsp-detach', {
                            clear = true
                        }),
                        callback = function(event2)
                            vim.lsp.buf.clear_references()
                            vim.api.nvim_clear_autocmds({
                                group = 'lsp-highlight',
                                buffer = event2.buf
                            })
                        end
                    })
                end

                -- Toggle inlay hints
                if client and client.supports_method(vim.lsp.protocol.Methods.textDocument_inlayHint) then
                    map('<leader>th', function()
                        vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled({
                            bufnr = event.buf
                        }))
                    end, '[T]oggle Inlay [H]ints')
                end
            end
        })


        local capabilities = vim.lsp.protocol.make_client_capabilities()
        capabilities = require('cmp_nvim_lsp').default_capabilities(capabilities)

        require('mason').setup()
        require('mason-lspconfig').setup({
            handlers = {
                function(server_name)
                    local server = lspconfig[server_name] or {}
                    server.capabilities = vim.tbl_deep_extend('force', {}, capabilities, server.capabilities or {})
                    require('lspconfig')[server_name].setup(server)
                end,
            },
        })
    end
}
