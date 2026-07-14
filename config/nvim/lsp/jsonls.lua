return {
  cmd = { "vscode-json-language-server", "--stdio" },
  filetypes = { "json", "jsonc" },
  init_options = {
    provideFormatter = true,
  },
  root_markers = { ".git" },
  settings = {
    json = {
      schemas = require("schemastore").json.schemas(),
      format = {
        enable = true,
      },
      validate = { enable = true },
    },
  },
}
