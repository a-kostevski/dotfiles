return {
   {
      "nvim-treesitter/nvim-treesitter",
      opts = function(_, opts)
         opts.highlight = opts.highlight or {}
         opts.ensure_installed = opts.ensure_installed or {}
         vim.list_extend(opts.ensure_installed, { "bibtex" })
         if type(opts.highlight.disable) == "table" then
            vim.list_extend(opts.highlight.disable, { "latex" })
         else
            opts.highlight.disable = { "latex" }
         end
      end,
   },
   {
      "lervag/vimtex",
      ft = "tex",
      init = function()
         vim.g.vimtex_mappings_disable = { ["n"] = { "K" } }
         vim.g.vimtex_quickfix_method = vim.fn.executable("pplatex") == 1 and "pplatex" or "latexlog"
         vim.g.vimtex_view_method = "skim"
         vim.g.tex_flavor = "latex"
      end,
      keys = {
         { "<localleader>l", group = "Latex", ft = "tex" },
      },
   },
   {
      "neovim/nvim-lspconfig",
      optional = true,
      opts = {
         servers = {
            texlab = {
               keys = {
                  { "<Leader>K", "<plug>(vimtex-doc-package)", desc = "Vimtex Docs", ft = "tex", silent = true },
               },
            },
         },
      },
   },
   {
      "williamboman/mason.nvim",
      optional = true,
      opts = {
         ensure_installed = {
            "texlab",
         },
      },
   },
}
