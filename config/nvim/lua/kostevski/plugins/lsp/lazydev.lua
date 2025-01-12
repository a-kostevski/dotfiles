return {
   {
      "folke/lazydev.nvim",
      ft = "lua",
      cmd = "LazyDev",
      opts = {
         library = {
            { path = "luvit-meta/library", words = { "vim%.uv" } },
         },
      },
   },
   { "Bilal2453/luvit-meta", lazy = true },
   {
      "saghen/blink.cmp",
      opts = {
         sources = {
            completion = {
               enabled_providers = { "lazydev" },
            },
            providers = {
               lsp = { fallback_for = { "lazydev" } },
               lazydev = { name = "LazyDev", module = "lazydev.integrations.blink" },
            },
         },
      },
   },
}
