local lang = require("kostevski.utils.lang")

return lang.register({
  name = "json",
  filetypes = { "json", "jsonc" },
  native_lsp = true, -- lsp/jsonls.lua handles LSP config
  root_markers = {
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
    -- VS Code JSON with comments
    "settings.json",
    "launch.json",
    "tasks.json",
    "keybindings.json",
  },
  lsp_server = "jsonls",
  formatters = {
    list = { "jq" },
    tools = { "jq" },
  },
  treesitter_parsers = { "json", "jsonc" },
  additional_plugins = {
    -- JSON Schema Store for better LSP experience
    {
      "b0o/SchemaStore.nvim",
      lazy = true,
      version = false,
    },
  },
})
