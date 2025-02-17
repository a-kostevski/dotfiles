return {
   -- LSP Configuration
   {
      "neovim/nvim-lspconfig",
      opts = {
         servers = {
            ruff = {
               cmd_env = { RUFF_TRACE = "messages" },
               init_options = {
                  settings = {
                     logLevel = "error",
                  },
               },
               keys = {
                  {
                     "<leader>co",
                     Utils.lsp.action["source.organizeImports"],
                     desc = "Organize Imports",
                  },
               },
            },
         },
         setup = {
            ruff = function()
               Utils.lsp.on_attach(function(client, _)
                  -- Disable hover in favor of Pyright
                  client.server_capabilities.hoverProvider = false
               end, ruff)
            end,
         },
      },
   },

   -- Formatter Configuration
   {
      "stevearc/conform.nvim",
      opts = {
         formatters_by_ft = {
            python = { "black", "isort" },
         },
         formatters = {
            black = {
               prepend_args = { "--line-length", "100" },
            },
            isort = {
               prepend_args = { "--profile", "black" },
            },
         },
      },
   },

   -- Linter Configuration
   {
      "mfussenegger/nvim-lint",
      opts = {
         linters_by_ft = {
            python = { "ruff", "mypy" },
         },
         linters = {
            mypy = {
               args = { "--ignore-missing-imports" },
            },
         },
      },
   },

   -- DAP Configuration
   {
      "mfussenegger/nvim-dap",
      optional = true,
      dependencies = {
         "mfussenegger/nvim-dap-python",
      },
      opts = function()
         local path = require("mason-registry").get_package("debugpy"):get_install_path()
         require("dap-python").setup(path .. "/venv/bin/python")
         return {
            adapters = {
               python = {
                  type = "executable",
                  command = "debugpy-adapter",
               },
            },
         }
      end,
   },

   -- Additional Tools
   {
      "nvim-treesitter/nvim-treesitter",
      opts = function(_, opts)
         if type(opts.ensure_installed) == "table" then
            vim.list_extend(opts.ensure_installed, { "python", "requirements" })
         end
      end,
   },

   {
      "nvim-neotest/neotest",
      optional = true,
      dependencies = {
         "nvim-neotest/neotest-python",
      },
      opts = {
         adapters = {
            ["neotest-python"] = {
               -- Here you can specify the settings for the adapter, i.e.
               -- runner = "pytest",
               -- python = ".venv/bin/python",
            },
         },
      },
   },

   -- Filetype-specific settings
   {
      "neovim/nvim-lspconfig",
      opts = {
         autoformat = true,
      },
      init = function()
         vim.api.nvim_create_autocmd("FileType", {
            pattern = "python",
            callback = function()
               vim.opt_local.expandtab = true
               vim.opt_local.shiftwidth = 4
               vim.opt_local.tabstop = 4
               vim.opt_local.softtabstop = 4
            end,
         })
      end,
   },
}
