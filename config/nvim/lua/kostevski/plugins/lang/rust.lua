return {
   -- LSP Configuration
   {
      "neovim/nvim-lspconfig",
      opts = {
         servers = {
            rust_analyzer = {
               settings = {
                  ["rust-analyzer"] = {
                     cargo = {
                        allFeatures = true,
                        loadOutDirsFromCheck = true,
                        runBuildScripts = true,
                     },
                     -- Add clippy lints for Rust
                     checkOnSave = {
                        allFeatures = true,
                        command = "clippy",
                        extraArgs = { "--no-deps" },
                     },
                     procMacro = {
                        enable = true,
                        ignored = {
                           ["async-trait"] = { "async_trait" },
                           ["napi-derive"] = { "napi" },
                           ["async-recursion"] = { "async_recursion" },
                        },
                     },
                  },
               },
            },
         },
      },
   },

   -- Formatter Configuration
   {
      "stevearc/conform.nvim",
      opts = {
         formatters_by_ft = {
            rust = { "rustfmt" },
         },
         formatters = {
            rustfmt = {
               args = { "--edition", "2021" },
            },
         },
      },
   },

   -- Linter Configuration
   {
      "mfussenegger/nvim-lint",
      opts = {
         linters_by_ft = {
            rust = { "clippy" },
         },
      },
   },

   -- DAP Configuration
   {
      "mfussenegger/nvim-dap",
      dependencies = {
         {
            "williamboman/mason.nvim",
            opts = function(_, opts)
               opts.ensure_installed = opts.ensure_installed or {}
               table.insert(opts.ensure_installed, "codelldb")
            end,
         },
      },
      opts = function()
         local codelldb = require("mason-registry").get_package("codelldb"):get_install_path()
            .. "/extension/adapter/codelldb"

         return {
            adapters = {
               codelldb = {
                  type = "server",
                  port = "${port}",
                  executable = {
                     command = codelldb,
                     args = { "--port", "${port}" },
                  },
               },
            },
            configurations = {
               rust = {
                  {
                     name = "Launch",
                     type = "codelldb",
                     request = "launch",
                     program = function()
                        return vim.fn.input("Path to executable: ", vim.fn.getcwd() .. "/target/debug/", "file")
                     end,
                     cwd = "${workspaceFolder}",
                     stopOnEntry = false,
                     args = {},
                     runInTerminal = false,
                  },
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
            vim.list_extend(opts.ensure_installed, { "rust", "toml" })
         end
      end,
   },

   -- Crates.io integration
   {
      "saecki/crates.nvim",
      event = { "BufRead Cargo.toml" },
      opts = {
         src = {
            cmp = { enabled = true },
         },
      },
   },
}
