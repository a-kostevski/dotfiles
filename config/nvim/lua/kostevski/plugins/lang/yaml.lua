-- Root patterns for YAML projects
require("kostevski.utils.root").add_patterns("yaml", {
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
})

return {
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
}
