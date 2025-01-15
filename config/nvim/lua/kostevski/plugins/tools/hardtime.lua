return {
   "m4xshen/hardtime.nvim",
   dependencies = { "MunifTanjim/nui.nvim", "nvim-lua/plenary.nvim" },
   init = function()
      vim.g.hardtime_enabled = vim.g.hardtime_enabled or false
      Utils.toggle.create({
         name = "hardtime",
         get = function()
            return vim.g.hardtime_enabled
         end,
         set = function(state)
            vim.cmd(":Hardtime toggle")
            vim.g.hardtime_enabled = state
         end,
         keymap = "<leader>tt",
         desc = "Hardtime",
      })
   end,
   opts = {
      enabled = vim.g.hardtime_enabled == true,
      disabled_filetypes = {
         "qf",
         "netrw",
         "lazy",
         "mason",
         "neo-tree",
         "aerial",
      },
   },
}
