return {
   "lukas-reineke/indent-blankline.nvim",
   event = { "BufReadPost", "BufNewFile" },
   main = "ibl",
   opts = {
      exclude = {
         filetypes = {
            "help",
            "neo-tree",
            "Trouble",
            "trouble",
            "lazy",
            "mason",
            "notify",
            "toggleterm",
         },
      },
   },
}
