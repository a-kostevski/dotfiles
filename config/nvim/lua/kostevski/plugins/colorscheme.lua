return {
   "catppuccin/nvim",
   flavor = "latte",
   name = "catppuccin",
   priority = 1000,
   opts = {
      integrations = {
         aerial = true,
         blink_cmp = true,
         flash = true,
         cmp = true,
         dashboard = true,
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
         noice = true,
         notify = true,
         telescope = true,
         treesitter = true,
         treesitter_context = true,
         which_key = true,
      },
   },
   config = function(_, opts)
      vim.cmd.colorscheme("catppuccin")
   end,
}
