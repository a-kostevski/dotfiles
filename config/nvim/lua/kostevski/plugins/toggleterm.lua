return {
   {
      "akinsho/toggleterm.nvim",
      lazy = true,
      cmd = { "ToggleTerm" },
      keys = {
         {
            "<leader>td",
            function()
               local count = vim.v.count1
               require("toggleterm").toggle(count, 15, Laz.root.get(), "horizontal")
            end,
            desc = "Open a horizontal terminal at the Desktop directory",
         },
      },
      opts = {
         size = 15,
         hide_numbers = true,
         shade_filetypes = {},
         shade_terminals = true,
         shading_factor = 2,
         start_in_insert = true,
         insert_mappings = true,
         persist_size = true,
         direction = "float",
         close_on_exit = true,
         shell = vim.o.shell,
         float_opts = {
            border = "curved",
            winblend = 0,
            highlights = {
               border = "Normal",
               background = "Normal",
            },
         },
      },
   },
}
