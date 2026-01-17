local lang = require("kostevski.utils.lang")

return lang.register({
  name = "lua",
  filetypes = { "lua" },
  native_lsp = true,
  root_markers = {
    ".luarc.json",
    ".luarc.jsonc",
    ".luacheckrc",
    "selene.toml",
    "stylua.toml",
    ".stylua.toml",
    "lua/",
    ".git",
  },
  lsp_server = "lua_ls",
  formatters = {
    list = { "stylua" },
    tools = { "stylua" },
  },
  linters = {
    list = { "selene" },
    tools = { "selene" },
  },
  treesitter_parsers = { "lua", "luadoc", "luap" },
  additional_plugins = {
    {
      "folke/lazydev.nvim",
      ft = "lua",
      opts = {
        library = {
          { path = "${3rd}/luv/library", words = { "vim%.uv" } },
        },
      },
    },
  },
})
