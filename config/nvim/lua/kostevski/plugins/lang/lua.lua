local lang = require("kostevski.utils.lang")

return lang.register({
  name = "lua",
  filetypes = { "lua" },
  native_lsp = true,
  root_markers = {
    ".luarc.json",
    ".luarc.jsonc",
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
  treesitter_parsers = { "lua", "luadoc", "luap" },
})
