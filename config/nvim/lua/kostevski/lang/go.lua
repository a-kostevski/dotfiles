return {
   {
      "nvim-treesitter/nvim-treesitter",
      opts = { ensure_installed = { "go", "gomod", "gowork", "gosum" } },
   },
   {
      "neovim/nvim-lspconfig",
      opts = {
         servers = {
            gopls = {
               settings = {
                  gopls = {
                     gofumpt = true,
                     codelenses = {
                        gc_details = false,
                        generate = true,
                        regenerate_cgo = true,
                        run_govulncheck = true,
                        test = true,
                        tidy = true,
                        upgrade_dependency = true,
                        vendor = true,
                     },
                     hints = {
                        assignVariableTypes = true,
                        compositeLiteralFields = true,
                        compositeLiteralTypes = true,
                        constantValues = true,
                        functionTypeParameters = true,
                        parameterNames = true,
                        rangeVariableTypes = true,
                     },
                     -- analyses = {
                     --    fieldalignment = true,
                     --    nilness = true,
                     --    unusedparams = true,
                     --    unusedwrite = true,
                     --    useany = true,
                     -- },
                     usePlaceholders = true,
                     completeUnimported = true,
                     staticcheck = true,
                     directoryFilters = { "-.git", "-.vscode", "-.idea", "-.vscode-test", "-node_modules" },
                     semanticTokens = true,
                  },
               },
            },
         },
         setup = {
            gopls = function(_, opts)
               -- workaround for gopls not supporting semanticTokensProvider
               -- https://github.com/golang/go/issues/54531#issuecomment-1464982242
               Utils.lsp.on_attach(function(client, _)
                  if not client.server_capabilities.semanticTokensProvider then
                     local semantic = client.config.capabilities.textDocument.semanticTokens
                     client.server_capabilities.semanticTokensProvider = {
                        full = true,
                        legend = {
                           tokenTypes = semantic.tokenTypes,
                           tokenModifiers = semantic.tokenModifiers,
                        },
                        range = true,
                     }
                  end
               end, "gopls")
               -- end workaround
            end,
         },
      },
   },
   -- Ensure Go tools are installed
   {
      "williamboman/mason.nvim",
      optional = true,
      opts = function(_, opts)
         opts.ensure_installed = opts.ensure_installed or {}
         opts.ensure_installed = vim.list_extend(opts.ensure_installed, { "goimports", "gofumpt" })
      end,
   },
   {
      "stevearc/conform.nvim",
      optional = true,
      opts = {
         formatters_by_ft = {
            go = { "goimports", "gofumpt" },
         },
      },
   },
}
