return {
   -- LSP Configuration
   {
      "neovim/nvim-lspconfig",
      opts = {
         servers = {
            texlab = {
               settings = {
                  texlab = {
                     build = {
                        onSave = true,
                        forwardSearchAfter = true,
                     },
                     forwardSearch = {
                        executable = "skim",
                        args = { "--synctex-forward", "%l:1:%f", "%p" },
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
            tex = { "latexindent" },
         },
      },
   },

   -- Additional Tools
   {
      "nvim-treesitter/nvim-treesitter",
      opts = function(_, opts)
         if type(opts.ensure_installed) == "table" then
            vim.list_extend(opts.ensure_installed, { "latex" })
         end
      end,
   },

   -- VimTeX Integration
   {
      "lervag/vimtex",
      lazy = false,
      config = function()
         vim.g.vimtex_view_method = "skim"
         vim.g.vimtex_compiler_method = "latexmk"
         vim.g.vimtex_quickfix_mode = 0
      end,
   },

   -- Filetype-specific settings
   {
      "neovim/nvim-lspconfig",
      init = function()
         vim.api.nvim_create_autocmd("FileType", {
            pattern = { "tex", "plaintex" },
            callback = function()
               vim.opt_local.wrap = true
               vim.opt_local.spell = true
               vim.opt_local.textwidth = 80
            end,
         })
      end,
   },
}
