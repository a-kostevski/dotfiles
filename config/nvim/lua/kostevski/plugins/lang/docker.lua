-- Root patterns for Docker projects
local lang = require("kostevski.utils.lang")

return lang.register({
  name = "Caddyfile",
  root_markers = {
    -- Docker files
    "Dockerfile",
    "dockerfile",
    "Dockerfile.*",
    "*.dockerfile",
    "*.Dockerfile",
    -- Docker Compose
    "docker-compose.yml",
    "docker-compose.yaml",
    "compose.yml",
    "compose.yaml",
    "docker-compose.*.yml",
    "docker-compose.*.yaml",
    -- Container configuration
    ".dockerignore",
    "docker-bake.json",
    "docker-bake.hcl",
    -- Build configurations
    "buildspec.yml", -- AWS CodeBuild
    ".gitlab-ci.yml", -- GitLab CI with Docker
    "cloudbuild.yaml", -- Google Cloud Build
    -- Kubernetes related
    "k8s/",
    "kubernetes/",
    "helm/",
    "charts/",
    "skaffold.yaml",
    -- Development
    "devcontainer.json",
    ".devcontainer/",
    ".git",
  },
  filetypes = { "Caddyfile" },

  lsp_server = "gopls",
  formatters = {
    list = { "gofumpt", "goimports" },
    tools = { "goimports", "gofumpt" },
  },
  linters = {
    list = { "hadolint" },
    tools = { "hadolint" },
  },
  additional_plugins = {
    { "isobit/vim-caddyfile" },
    {
      "mfussenegger/nvim-lint",
      opts = {
        linters_by_ft = {
          dockerfile = { "hadolint" },
        },
      },
    },
  },
  treesitter_parsers = { "dockerfile" },
})
