-- SchemaStore.nvim is only installed when the json language is enabled in
-- config/languages.lua; guard so a stray Mason-installed jsonls can't crash startup
local ok, schemastore = pcall(require, "schemastore")

return {
  cmd = { "vscode-json-language-server", "--stdio" },
  filetypes = { "json", "jsonc" },
  init_options = {
    provideFormatter = true,
  },
  root_markers = { ".git" },
  settings = {
    json = {
      schemas = ok and schemastore.json.schemas() or nil,
      format = {
        enable = true,
      },
      validate = { enable = true },
    },
  },
}
