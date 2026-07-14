local lang = require("kostevski.utils.lang")

return lang.register({
  name = "docker",
  filetypes = { "dockerfile", "yaml.docker-compose" },
  root_markers = {
    "Dockerfile",
    "docker-compose.yaml",
    "docker-compose.yml",
    "compose.yaml",
    "compose.yml",
    "docker-bake.json",
    "docker-bake.hcl",
    "docker-bake.override.json",
    "docker-bake.override.hcl",
    ".git",
  },
  lsp_server = "docker_language_server",
  formatters = {
    list = {},
    tools = { "dockerfmt", "yamlfmt" },
    by_ft = {
      dockerfile = { "dockerfmt" },
      ["yaml.docker-compose"] = { "yamlfmt" },
    },
  },
  linters = {
    list = {},
    tools = { "hadolint" },
    by_ft = {
      dockerfile = { "hadolint" },
    },
  },
  treesitter_parsers = { "dockerfile", "yaml" },
})
