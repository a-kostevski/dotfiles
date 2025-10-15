local lang = require("kostevski.utils.lang")

return lang.register({
  name = "shell",
  filetypes = { "zsh", "sh" },
  root_markers = {
    -- Zsh specific
    ".zshrc",
    ".zshenv",
    ".zprofile",
    ".zlogin",
    ".zlogout",
    ".zsh_history",
    ".zcompdump",
    -- Shell script indicators
    ".shellcheckrc",
    -- oh-my-zsh
    ".oh-my-zsh",
    "custom/plugins",
    "custom/themes",
    -- Project files
    "Makefile",
    "makefile",
    -- CI/CD
    ".gitlab-ci.yml",
    ".github",
    -- Version control
    ".git",
  },
  lsp_server = {
    name = "bashls",
    config = {
      filetypes = { "sh", "zsh" },
      settings = {
        bashIde = {
          globPattern = "*@(.sh|.inc|.zsh|.command)",
          shellcheckPath = "shellcheck",
          includeAllWorkspaceSymbols = true,
          explainshellEndpoint = "",
          shellcheckArguments = { "-x", "-s", "bash" },
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
    list = { "shellcheck", "zsh" },
    tools = { "shellcheck" },
    config = {
      shellcheck = {
        args = { "--format", "json", "-x", "-s", "bash", "-" },
      },
    },
  },
  treesitter_parsers = { "bash" }, -- Note: zsh uses bash parser
  settings = {
    expandtab = true,
    shiftwidth = 2,
    tabstop = 2,
    softtabstop = 2,
  },
  additional_plugins = {
    -- Zsh specific plugins
    {
      "zsh-users/zsh-syntax-highlighting",
      optional = true,
    },
    {
      "zsh-users/zsh-autosuggestions",
      optional = true,
    },
  },
})

