return {
   "echasnovski/mini.bufremove",
   version = false,
   keys = {
      {
         "<leader>bd",
         function(b)
            require("mini.bufremove").delete(b, false)
         end,
         desc = "Close Buffer",
      },
   },
   opts = true,
}
