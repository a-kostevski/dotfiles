return {
   "akinsho/bufferline.nvim",
   event = "VeryLazy",
   dependencies = { "nvim-tree/nvim-web-devicons" },
   keys = {
      { "<leader>bp", "<Cmd>BufferLineTogglePin<CR>", desc = "Toggle Pin" },
      { "<leader>bP", "<Cmd>BufferLineGroupClose ungrouped<CR>", desc = "Delete Non-Pinned Buffers" },
      { "<leader>bo", "<Cmd>BufferLineCloseOthers<CR>", desc = "Delete Other Buffers" },
      { "<leader>br", "<Cmd>BufferLineCloseRight<CR>", desc = "Delete Buffers to the Right" },
      { "<leader>bl", "<Cmd>BufferLineCloseLeft<CR>", desc = "Delete Buffers to the Left" },
      { "<S-h>", "<cmd>BufferLineCyclePrev<cr>", desc = "Prev Buffer" },
      { "<S-l>", "<cmd>BufferLineCycleNext<cr>", desc = "Next Buffer" },
      { "[b", "<cmd>BufferLineCyclePrev<cr>", desc = "Prev Buffer" },
      { "]b", "<cmd>BufferLineCycleNext<cr>", desc = "Next Buffer" },
      { "[B", "<cmd>BufferLineMovePrev<cr>", desc = "Move buffer prev" },
      { "]B", "<cmd>BufferLineMoveNext<cr>", desc = "Move buffer next" },
      {
         "L",
         function()
            vim.cmd("bnext " .. vim.v.count1)
         end,
         desc = "Next buffer",
      },
      {
         "H",
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
   },
   opts = {
      options = {
         close_command = function(b)
            require("mini.bufremove").delete(b, false)
         end,
         right_mouse_command = function(b)
            require("mini.bufremove").delete(b, false)
         end,

         diagnostics = "nvim_lsp",

         always_show_bufferline = false,
         offsets = {
            {
               filetype = "neo-tree",
               text = "File Explorer",
               highlight = "Directory",
            },
         },
      },
   },
   config = function(_, opts)
      require("bufferline").setup(opts)
      vim.api.nvim_create_autocmd({ "BufAdd", "BufDelete" }, {
         callback = function()
            vim.schedule(function()
               pcall(nvim_bufferline)
            end)
         end,
      })
   end,
}
