local icons = Utils.ui.icons

return {
   "folke/which-key.nvim",
   event = "VeryLazy",
   keys = {
      {
         "<leader>?",
         function()
            require("which-key").show({ global = false })
         end,
         desc = "Buffer Local Keymaps (which-key)",
      },
   },
   opts_extend = { "spec" },
   opts = {
      preset = "classic",
      plugins = {
         presets = {
            operators = true,
            motions = true,
            text_objects = true,
            windows = true,
            nav = true,
            z = true,
            g = true,
         },
      },
      icons = {
         breadcrumb = "»",
         separator = "➜",
         group = "> ",
         ellipsis = "…",
         mappings = true,
         rules = {},
         colors = true,
         keys = icons.keys,
      },
      win = {
         border = "rounded",
         padding = { 2, 2, 2, 2 },
      },
      layout = {
         height = { min = 4, max = 25 },
         width = { min = 20, max = 50 },
         spacing = 4,
         align = "left",
      },

      sort = { "alphanum", "group", "local", "order", "mod" },
      replace = {
         key = {
            function(key)
               return require("which-key.view").format(key)
            end,
         },
         desc = {
            { "<Plug>%(?(.*)%)?", "%1" },
            { "^%+", "" },
            { "<[cC]md>", "" },
            { "<[cC][rR]>", "" },
            { "<[sS]ilent>", "" },
            { "^lua%s+", "" },
            { "^call%s+", "" },
            { "^:%s*", "" },
         },
      },
      show_help = true,
      show_keys = true,
      expand = 0,
      spec = {
         {
            mode = { "n", "v" },
            { "<leader>a", group = "Ai" },
            { "<leader>b", group = "Buffer" },
            { "<leader>bb", "<cmd>e #<cr>", desc = "Switch to Other Buffer" },
            {
               "<leader>bd",
               function()
                  Utils.ui.bufremove()
               end,
               desc = "Delete",
            },
            { "<leader>bD", "<cmd>:bd<cr>", desc = "Delete Buffer and Window" },
            { "<leader>bn", "<cmd>bnext<cr>", desc = "Next buffer" },
            { "<leader>bp", "<Cmd>BufferLineTogglePin<CR>", desc = "Toggle Pin" },
            { "<leader>bP", "<Cmd>BufferLineGroupClose ungrouped<CR>", desc = "Delete Non-Pinned Buffers" },
            { "<leader>bo", "<Cmd>BufferLineCloseOthers<CR>", desc = "Delete Other Buffers" },
            { "<leader>br", "<Cmd>BufferLineCloseRight<CR>", desc = "Delete Buffers to the Right" },
            { "<leader>bl", "<Cmd>BufferLineCloseLeft<CR>", desc = "Delete Buffers to the Left" },
            { "[B", "<cmd>BufferLineMovePrev<cr>", desc = "Move buffer prev" },
            { "]B", "<cmd>BufferLineMoveNext<cr>", desc = "Move buffer next" },
            {
               "<S-l>",
               function()
                  vim.cmd("bnext " .. vim.v.count1)
               end,
               desc = "Next buffer",
            },
            {
               "<S-h>",
               function()
                  vim.cmd("bprev " .. vim.v.count1)
               end,
               desc = "Previous buffer",
            },
            {
               "]b",
               function()
                  vim.cmd("bnext " .. vim.v.count1)
               end,
               desc = "Next buffer",
            },
            {
               "[b",
               function()
                  vim.cmd("bprev " .. vim.v.count1)
               end,
               desc = "Previous buffer",
            },
            { "<leader>c", group = "Code" },
            { "<leader>d", group = "Debug" },
            { "<leader>f", group = "Find/file" },
            { "<leader>g", group = "Git" },
            { "<leader>gh", group = "Hunks" },
            { "<leader>n", group = "Notes" },
            { "<leader>q", group = "Quit/session" },
            { "<leader>s", group = "Search" },
            { "<leader>t", group = "Toggle", icon = { icon = "󰙵 ", color = "cyan" } },
            {
               "<leader>w",
               group = "Windows",
               proxy = "<c-w>",
               expand = function()
                  return require("which-key.extras").expand.win()
               end,
            },
            { "<leader>x", group = "Quickfix/Diagnostic", icon = { icon = "󱖫 ", color = "green" } },

            { "<leader><tab>", group = "Tabs", icon = "_" },
            { "<leader><tab>l", "<cmd>tablast<cr>", desc = "Last Tab" },
            { "<leader><tab>o", "<cmd>tabonly<cr>", desc = "Close Other Tabs" },
            { "<leader><tab>f", "<cmd>tabfirst<cr>", desc = "First Tab" },
            { "<leader><tab><tab>", "<cmd>tabnew<cr>", desc = "New Tab" },
            { "<leader><tab>]", "<cmd>tabnext<cr>", desc = "Next Tab" },
            { "<leader><tab>d", "<cmd>tabclose<cr>", desc = "Close Tab" },
            { "<leader><tab>[", "<cmd>tabprevious<cr>", desc = "Previous Tab" },
            { "g", group = "Goto" },
            { "gc", group = "Comment" },
            { "gcc", desc = "Toggle line" },
            { "gco", "o<esc>Vcx<esc><cmd>normal gcc<cr>fxa<bs>", desc = "Add Comment Below", mode = { "n", "v" } },
            { "gcO", "O<esc>Vcx<esc><cmd>normal gcc<cr>fxa<bs>", desc = "Add Comment Above" },
            { "z", group = "Fold" },
            { "[", group = "Previous" },
            { "]", group = "Next" },
            -- better descriptions
            { "gx", desc = "Open with system app" },
            { "<BS>", desc = "Decrement Selection", mode = "x" },
            { "<c-space>", desc = "Increment Selection", mode = { "x" } },
         },
      },
   },
}
