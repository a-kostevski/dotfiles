return {
   {
      "folke/lazydev.nvim",
      ft = "lua", -- only load on lua files
      opts = {
         library = {
            { path = "${3rd}/luv/library", words = { "vim%.uv" } },
         },
      },
   },
   { "Bilal2453/luvit-meta", lazy = true },
   {
      "saghen/blink.cmp",
      opts = {
         sources = {
            default = { "lazydev" },
            providers = {
               lazydev = {
                  name = "LazyDev",
                  module = "lazydev.integrations.blink",
                  score_offset = 100, -- show at a higher priority than lsp
               },
            },
         },
      },
   },
}
