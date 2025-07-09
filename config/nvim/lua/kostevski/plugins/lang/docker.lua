-- Root patterns for Docker projects
require("kostevski.utils.root").add_patterns("dockerfile", {
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
})

return {
   {
      "mason",
      opts = { ensure_installed = { "hadolint" } },
   },

   -- Linter Configuration
   {
      "mfussenegger/nvim-lint",
      opts = {
         linters_by_ft = {
            dockerfile = { "hadolint" },
         },
      },
   },

   -- Treesitter
   {
      "nvim-treesitter/nvim-treesitter",
      opts = function(_, opts)
         opts.ensure_installed = opts.ensure_installed or {}
         vim.list_extend(opts.ensure_installed, { "dockerfile" })
      end,
   },
}
