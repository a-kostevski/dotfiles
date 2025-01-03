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
   { "Bilal2453/luvit-meta", lazy = true }, -- optional `vim.uv` typings
   { -- optional blink completion source for require statements and module annotations
      "saghen/blink.cmp",
      opts = {
         sources = {
            -- add lazydev to your completion providers
            completion = {
               enabled_providers = { "lazydev" },
            },
            providers = {
               --    -- dont show LuaLS require statements when lazydev has items
               --    lsp = { fallback_for = { "lazydev" } },
               lazydev = { name = "LazyDev", module = "lazydev.integrations.blink" },
            },
         },
      },
   },
}
