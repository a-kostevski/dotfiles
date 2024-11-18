return {
   {
      "L3MON4D3/LuaSnip",
      build = "make install_jsregexp",
      dependencies = {
         {
            "rafamadriz/friendly-snippets",
            config = function()
               require("luasnip.loaders.from_vscode").lazy_load()
            end,
         },
      },
      opts = { history = true, delete_check_events = "TextChanged" },
   },
   {
      "saghen/blink.cmp",
      optional = true,
      opts = {
         accept = {
            expand_snippet = function(...)
               return require("luasnip").lsp_expand(...)
            end,
         },
      },
   },
}
