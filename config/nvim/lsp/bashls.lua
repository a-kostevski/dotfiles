---@brief
---
--- https://github.com/bash-lsp/bash-language-server
---
--- Bash language server for shell script development.
--- Provides completions, hover, diagnostics, and more.

return {
  cmd = { "bash-language-server", "start" },
  filetypes = { "sh", "bash", "zsh" },
  root_dir = function(fname)
    return vim.fs.root(fname, {
      ".shellcheckrc",
      ".bashrc",
      ".bash_profile",
      ".zshrc",
      ".zshenv",
      "Makefile",
      ".git",
    })
  end,
  settings = {
    bashIde = {
      -- Glob pattern to match files for analysis
      globPattern = "*@(.sh|.inc|.bash|.zsh|.command)",

      -- Path to shellcheck executable
      shellcheckPath = "shellcheck",

      -- Include all workspace symbols in completion
      includeAllWorkspaceSymbols = true,

      -- Explainshell.com integration (empty to disable)
      explainshellEndpoint = "",

      -- Additional arguments to pass to shellcheck
      shellcheckArguments = {
        "-x", -- Follow source/. directives
        "--external-sources", -- Check sourced files
      },

      -- Enable/disable specific features
      enableSourceErrorDiagnostics = true,

      -- Background analysis delay (ms)
      backgroundAnalysisMaxFiles = 500,
    },
  },
  capabilities = {
    -- Enable workspace configuration
    workspace = {
      configuration = true,
    },
  },
  -- No on_attach format-on-save here: conform.nvim owns formatting; an LSP
  -- BufWritePre format would double-format shell buffers
}
