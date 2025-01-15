return {
   "mbbill/undotree",
   name = "undotree",
   dependencies = "nvim-lua/plenary.nvim",
   init = function()
      vim.g.undotree_enabled = vim.g.undotree_enabled or true
   end,
   config = function(_, opts)
      Utils.toggle.create({
         name = "undotree",
         get = function()
            return vim.g.undotree_enabled
         end,
         set = function(_)
            return vim.cmd.UndotreeToggle()
         end,
         keymap = "<leader>tu",
         desc = "Undotree",
      })
   end,
}
