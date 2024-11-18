return {
   "folke/which-key.nvim",
   event = "VeryLazy",
   opts_extend = { "spec" },
   opts = {
      spec = {
         mode = { "n", "v" },
         { "<leader><tab>", group = "tabs" },
         { "<leader>c", group = "code" },
         { "<leader>f", group = "file/find" },
         { "<leader>g", group = "git" },
         { "<leader>gh", group = "hunks" },
         { "<leader>q", group = "quit/session" },
         { "<leader>s", group = "search" },
         { "<leader>u", group = "ui", icon = { icon = "󰙵 ", color = "cyan" } },
         { "<leader>x", group = "diagnostics/quickfix", icon = { icon = "󱖫 ", color = "green" } },
         { "[", group = "prev" },
         { "]", group = "next" },
         { "g", group = "goto" },
         { "gs", group = "surround" },
         { "z", group = "fold" },
         {
            "<leader>b",
            group = "Buffer",
            expand = function()
               return require("which-key.extras").expand.buf()
            end,
         },
         {
            "<leader>w",
            group = "windows",
            proxy = "<c-w>",
            expand = function()
               return require("which-key.extras").expand.win()
            end,
         },
         -- better descriptions
         { "gx", desc = "Open with system app" },
         { "<BS>", desc = "Decrement Selection", mode = "x" },
         { "<c-space>", desc = "Increment Selection", mode = { "x", "n" } },
      },
   },
   keys = {
      {
         "<leader>?",
         function()
            require("which-key").show({ global = false })
         end,
         desc = "Buffer Local Keymaps (which-key)",
      },
      {
         "<c-w><space>",
         function()
            require("which-key").show({ keys = "<c-w>", loop = true })
         end,
         desc = "Window Hydra Mode (which-key)",
      },
   },
   config = function(_, opts)
      require("which-key").setup(opts)
   end,
}