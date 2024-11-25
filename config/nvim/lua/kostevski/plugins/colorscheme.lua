return {
   {
      "catppuccin/nvim",
      flavor = "latte",
      name = "catppuccin",
      priority = 1000,
      opts = {
         integrations = {
            blink_cmp = true,
            flash = true,
            dap = true,
            dap_ui = true,
            gitsigns = true,
            grug_far = true,
            indent_blankline = { enabled = true },
            mason = true,
            markdown = true,
            mini = true,
            native_lsp = {
               enabled = true,
               underlines = {
                  errors = { "undercurl" },
                  hints = { "undercurl" },
                  warnings = { "undercurl" },
                  information = { "undercurl" },
               },
            },
            neotree = true,
            notify = true,
            telescope = true,
            treesitter = true,
            treesitter_context = true,
            which_key = true,
         },
      },
      init = function() vim.cmd.colorscheme("catppuccin") end,
   },
   {
      "folke/tokyonight.nvim",
      enabled = false,
      priority = 1000,
   },
}
