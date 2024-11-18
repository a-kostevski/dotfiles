return {
   "echasnovski/mini.surround",
   event = "VeryLazy",
   opts = {
      modes = { insert = true, command = true, terminal = false },
      skip_ts = { "string" },
      skip_unbalanced = true,
      markdown = true,
      mappings = {
         add = "gsa", -- Add surrounding in Normal and Visual modes
         delete = "gsd", -- Delete surrounding
         find = "gsf", -- Find surrounding (to the right)
         find_left = "gsF", -- Find surrounding (to the left)
         highlight = "gsh", -- Highlight surrounding
         replace = "gsr", -- Replace surrounding
         update_n_lines = "gsn", -- Update `n_lines`
      },
   },
   keys = {
      { "gsa", desc = "Add Surrounding", mode = { "n", "v" } },
      { "gsd", desc = "Delete Surrounding" },
      { "gsf", desc = "Find Right Surrounding" },
      { "gsF", desc = "Find Left Surrounding" },
      { "gsh", desc = "Highlight Surrounding" },
      { "gsr", desc = "Replace Surrounding" },
      { "gsn", desc = "Update `MiniSurround.config.n_lines`" },
   },
}
