return {
   {
      "Saecki/crates.nvim",
      event = { "BufRead Cargo.toml" },
      opts = {
         completion = {
            crates = {
               enabled = true,
            },
         },
         lsp = {
            enabled = true,
            actions = true,
            completion = true,
            hover = true,
         },
      },
   },
   {
      "mrcjkb/rustaceanvim",
      version = "^5", -- Recommended
      ft = "rust",
      opts = {
         tools = {
            hover_actions = {
               replace_builtin_hover = false,
            },
            code_actions = {
               ui_select_fallback = true,
            },
            enable_clippy = true,
            test_executor = "background",
         },
         server = {
            on_attach = function(_, bufnr)
               vim.keymap.set("n", "<leader>rc", function()
                  vim.cmd.RustLsp("codeAction")
               end, { desc = "Code Action", buffer = bufnr })
               vim.keymap.set("n", "<leader>dr", function()
                  vim.cmd.RustLsp("debuggables")
               end, { desc = "Rust Debuggables", buffer = bufnr })
            end,

            default_settings = {
               ["rust-analyzer"] = {
                  assist = {
                     importGranularity = "module",
                     importPrefix = "self",
                  },
                  autoSetHints = true,
                  hoverWithActions = true,
                  inlayHints = {
                     chainingHints = true,
                     typeHints = true,
                     parameterHints = true,
                     otherHints = true,
                  },
                  runnables = {
                     use_telescope = true,
                  },
                  debuggables = {
                     use_telescope = true,
                  },

                  cargo = {
                     allFeatures = true,
                     features = "all",
                     loadOutDirsFromCheck = true,
                     buildScripts = {
                        enable = true,
                     },
                  },
                  checkOnSave = {
                     enable = true,
                     command = "clippy",
                     features = "all",
                  },
                  diagnostics = {
                     enable = true,
                     enableExperimental = true,
                     styleLints = {
                        enable = true,
                        -- toml = {
                        --    enable = true,
                        -- },
                     },
                  },
                  imports = {
                     granularity = {
                        group = "crate",
                     },
                     merge = {
                        group = true,
                        use = true,
                        extern_crate_name = true,
                        extern_crate_rename = true,
                     },
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
      config = function(_, opts)
         vim.g.rustaceanvim = vim.tbl_deep_extend("keep", vim.g.rustaceanvim or {}, opts or {})
      end,
   },
   {
      "williamboman/mason.nvim",
      optional = true,
      opts = function(_, opts)
         opts.ensure_installed = opts.ensure_installed or {}
         opts.ensure_installed = vim.list_extend(opts.ensure_installed, {
            "codelldb",
         })
      end,
   },
   {
      "nvim-treesitter/nvim-treesitter",
      opts = function(_, opts)
         opts.ensure_installed = opts.ensure_installed or {}
         vim.list_extend(opts.ensure_installed, {
            ensure_installed = {
               "ron",
               "rust",
            },
         })
      end,
   },
   {
      "stevearc/conform.nvim",
      opts = function(_, opts)
         table.insert(opts.formatters_by_ft, { rust = { "rustfmt", lsp_format = "fallback" } })
      end,
   },
   {
      "neovim/nvim-lspconfig",
      opts = {
         servers = {
            taplo = {
               keys = {
                  {
                     "K",
                     function()
                        if vim.fn.expand("%:t") == "Cargo.toml" and require("crates").popup_available() then
                           require("crates").show_popup()
                        else
                           vim.lsp.buf.hover()
                        end
                     end,
                     desc = "Show Crate Documentation",
                  },
               },
            },
         },
      },
   },
}
