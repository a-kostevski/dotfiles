return {
   {
      "L3MON4D3/LuaSnip",
      build = "make install_jsregexp",
      dependencies = {
         {
            "rafamadriz/friendly-snippets",
            config = function()
               require("luasnip").filetype_extend("markdown_inline", { "markdown" })
               require("luasnip.loaders.from_lua").lazy_load({ paths = { vim.fn.stdpath("config") .. "/snippets" } })
               require("luasnip.loaders.from_vscode").lazy_load()
               -- require("luasnip.loaders.from_vscode").lazy_load({ paths = { vim.fn.stdpath("config") .. "/snippets" } })
            end,
         },
      },
      opts = { history = true, delete_check_events = "TextChanged" },
   },
}
