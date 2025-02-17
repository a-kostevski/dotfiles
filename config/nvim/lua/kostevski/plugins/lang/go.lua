return {
   -- LSP Configuration
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
   {
      "williamboman/mason.nvim",
      optional = true,
      opts = { ensure_installed = { "goimports", "gofumpt" } },
   },

   -- Formatter Configuration
   {
      "stevearc/conform.nvim",
      opts = {
         formatters_by_ft = {
            go = { "gofumpt", "goimports" },
         },
      },
   },

   -- Linter Configuration
   {
      "mfussenegger/nvim-lint",
      opts = {
         linters_by_ft = {
            go = { "golangci-lint" },
         },
      },
   },

   -- DAP Configuration
   {
      "mfussenegger/nvim-dap",
      optional = true,
      opts = function()
         require("dap-go").setup()
         return {
            adapters = {
               delve = {
                  type = "server",
                  port = "${port}",
                  executable = {
                     command = "dlv",
                     args = { "dap", "-l", "127.0.0.1:${port}" },
                  },
               },
            },
         }
      end,
   },

   -- Neotest
   {
      "nvim-neotest/neotest",
      optional = true,
      dependencies = {
         "fredrikaverpil/neotest-golang",
      },
      opts = {
         adapters = {
            ["neotest-golang"] = {
               -- Here we can set options for neotest-golang, e.g.
               -- go_test_args = { "-v", "-race", "-count=1", "-timeout=60s" },
               dap_go_enabled = true, -- requires leoluz/nvim-dap-go
            },
         },
      },
   },
   -- Additional Tools
   {
      "nvim-treesitter/nvim-treesitter",
      opts = function(_, opts)
         if type(opts.ensure_installed) == "table" then
            vim.list_extend(opts.ensure_installed, { "go", "gomod", "gowork", "gosum" })
         end
      end,
   },
}
