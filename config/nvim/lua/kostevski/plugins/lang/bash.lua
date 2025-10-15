local lang = require("kostevski.utils.lang")

return lang.register({
  name = "bash",
  filetypes = { "sh", "bash" },
  root_patterns = {
    -- Shell script indicators
    ".shellcheckrc",
    ".bashrc",
    ".bash_profile",
    ".bash_login",
    ".profile",
    -- Project files
    "Makefile",
    "makefile",
    "GNUmakefile",
    -- CI/CD
    ".gitlab-ci.yml",
    ".github",
    -- Package management
    "package.json",
    "Gemfile",
    -- Version control
    ".git",
  },
  lsp_server = {
    name = "bashls",
    config = {
      filetypes = { "sh", "bash" },
      settings = {
        bashIde = {
          globPattern = "*@(.sh|.inc|.bash|.command)",
          shellcheckPath = "shellcheck",
          includeAllWorkspaceSymbols = true,
          explainshellEndpoint = "",
          shellcheckArguments = { "-x" },
        },
      },
    },
  },
  formatters = {
    list = { "shfmt", "beautysh" },
    tools = { "shfmt", "beautysh" },
    config = {
      shfmt = {
        prepend_args = { "-i", "2", "-ci", "-bn" },
      },
    },
  },
  linters = {
    list = { "shellcheck" },
    tools = { "shellcheck" },
    config = {
      shellcheck = {
        args = { "--format", "json", "-x", "-" },
      },
    },
  },
  treesitter_parsers = { "bash" },
  settings = {
    expandtab = true,
    shiftwidth = 2,
    tabstop = 2,
    softtabstop = 2,
  },
  additional_plugins = {
    -- Shell script specific plugins
    {
      "bash-lsp/bash-language-server",
      optional = true,
    },
  },
})
