return {
   "mbbill/undotree",
   dependencies = "nvim-lua/plenary.nvim",
   config = function()
      Utils.toggle.create({
         name = "undotree",
         get = function() end,
         set = function()
            require("undotree").toggle()
         end,
         keymap = "<leader>uu",
         desc = "Undotree",
      })
   end,
}
