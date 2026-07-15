-- SchemaStore.nvim is only installed when the yaml language is enabled in
-- config/languages.lua; guard so a stray Mason-installed yamlls can't crash startup
local ok, schemastore = pcall(require, "schemastore")

return {
  cmd = { "yaml-language-server", "--stdio" },
  filetypes = { "yaml", "yaml.docker-compose", "yaml.gitlab" },
  root_markers = { ".git" },
  settings = {
    redhat = { telemetry = { enabled = false } },
    yaml = {
      schemas = ok and schemastore.yaml.schemas() or nil,
      keyOrdering = false,
      format = {
        enable = true,
      },
      validate = true,
      schemaStore = {
        enable = false,
        url = "",
      },
    },
  },
}
