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
            render_markdown = true,
            telescope = true,
            treesitter = true,
            treesitter_context = true,
            which_key = true,
         },
      },
   },
   {
      "folke/tokyonight.nvim",
      lazy = false,
      priority = 1000,
      init = function()
         vim.cmd.colorscheme("tokyonight")
      end,
      opts = {
         style = "night",
      },
   },
   {
      "shaunsingh/nord.nvim",
      priority = 1000,
   },
}
