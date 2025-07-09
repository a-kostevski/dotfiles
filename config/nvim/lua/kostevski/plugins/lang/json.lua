-- Root patterns for JSON projects
require("kostevski.utils.root").add_patterns("json", {
   -- Node.js/JavaScript
   "package.json",
   "package-lock.json",
   "npm-shrinkwrap.json",
   "yarn.lock",
   "pnpm-lock.yaml",
   "bun.lockb",
   -- TypeScript
   "tsconfig.json",
   "tsconfig.*.json",
   "jsconfig.json",
   -- Configuration files
   ".eslintrc.json",
   ".prettierrc.json",
   ".stylelintrc.json",
   "tslint.json",
   ".babelrc.json",
   -- Build/bundler configs
   "angular.json", -- Angular
   "nx.json", -- Nx monorepo
   "lerna.json", -- Lerna
   "rush.json", -- Rush
   "turbo.json", -- Turborepo
   -- Testing
   "jest.config.json",
   "cypress.json",
   "playwright.config.json",
   -- IDE/Editor
   ".vscode/settings.json",
   ".idea/",
   "workspace.json",
   -- Cloud/deployment
   "vercel.json",
   "netlify.json",
   "now.json",
   "app.json", -- Heroku
   "firebase.json",
   -- API/Schema
   "openapi.json",
   "swagger.json",
   "schema.json",
})

-- Also add patterns for jsonc (JSON with comments)
require("kostevski.utils.root").add_patterns("jsonc", {
   "tsconfig.json",
   "jsconfig.json",
   ".eslintrc.json",
   "settings.json",
   "launch.json",
   "tasks.json",
   "keybindings.json",
})

return {
   {
      "b0o/SchemaStore.nvim",
      lazy = true,
      version = false,
   },
   -- Formatter Configuration
   {
      "stevearc/conform.nvim",
      opts = {
         formatters_by_ft = {
            json = { "jq" },
            jsonc = { "jq" },
         },
      },
   },

   -- Additional Tools
   {
      "nvim-treesitter/nvim-treesitter",
      opts = function(_, opts)
         if type(opts.ensure_installed) == "table" then
            vim.list_extend(opts.ensure_installed, { "json", "jsonc" })
         end
      end,
   },
}
