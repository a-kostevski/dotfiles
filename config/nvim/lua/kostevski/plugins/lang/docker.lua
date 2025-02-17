require("kostevski.utils.root").add_patterns("dockerfile", {
   "Dockerfile",
   "dockerfile",
   "docker-compose.yml",
   "docker-compose.yaml",
})

return {
   {
      "mason.nvim",
      opts = { ensure_installed = { "hadolint" } },
   },

   -- LSP Configuration
   {
      "neovim/nvim-lspconfig",
      opts = {
         servers = {
            dockerls = {},
            docker_compose_language_service = {},
         },
      },
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
