local lang = require("kostevski.utils.lang")

return lang.register({
  name = "yaml",
  filetypes = { "yaml" },
  native_lsp = true, -- lsp/yamlls.lua handles LSP config
  lsp_server = "yamlls",
  root_markers = {
    -- CI/CD
    ".github/workflows/",
    ".gitlab-ci.yml",
    ".travis.yml",
    "circle.yml",
    ".circleci/config.yml",
    "azure-pipelines.yml",
    ".drone.yml",
    "Jenkinsfile",
    -- Kubernetes
    "k8s/",
    "kubernetes/",
    "helm/",
    "charts/",
    "Chart.yaml",
    "values.yaml",
    "kustomization.yaml",
    -- Docker
    "docker-compose.yml",
    "docker-compose.yaml",
    "compose.yml",
    "compose.yaml",
    -- Ansible
    "ansible.cfg",
    "playbook.yml",
    "playbook.yaml",
    "site.yml",
    "site.yaml",
    "inventory/",
    "roles/",
    -- Application configs
    "app.yml",
    "app.yaml",
    "application.yml",
    "application.yaml",
    "config.yml",
    "config.yaml",
    "settings.yml",
    "settings.yaml",
    -- Package managers
    "pubspec.yaml", -- Dart/Flutter
    "environment.yml", -- Conda
    "environment.yaml",
    ".pre-commit-config.yaml",
  },
  additional_plugins = {
    -- YAML Schema Store for better LSP experience
    {
      "b0o/SchemaStore.nvim",
      lazy = true,
      version = false,
      config = function()
        vim.lsp.config("yamlls", {
          capabilities = {
            textDocument = {
              foldingRange = {
                dynamicRegistration = false,
                lineFoldingOnly = true,
              },
            },
          },
        })
      end,
    },
  },
})
