-- Refactored Go configuration using the new language utility
-- This shows how the existing go.lua can be simplified

local lang = require("kostevski.utils.lang")

return lang.register({
  name = "go",
  filetypes = { "go", "gomod", "gowork", "gotmpl" },
  native_lsp = true, -- lsp/gopls.lua handles LSP config
  root_markers = {
    -- Go modules
    "go.mod",
    "go.sum",
    "go.work",
    "go.work.sum",
    -- Legacy dependency management
    "Gopkg.toml",
    "Gopkg.lock",
    "glide.yaml",
    "glide.lock",
    "vendor/",
    -- Go-specific config
    ".golangci.yml",
    ".golangci.yaml",
    ".golangci.toml",
    ".goreleaser.yml",
    ".goreleaser.yaml",
    -- Testing
    "testdata/",
    -- Build
    "Makefile",
    "Taskfile.yml",
    "Taskfile.yaml",
    "magefile.go",

    ".git",
  },
  lsp_server = "gopls",
  formatters = {
    list = { "gofumpt", "goimports" },
    tools = { "goimports", "gofumpt" },
  },
  linters = {
    list = { "golangci-lint" },
    tools = { "golangci-lint" },
  },
  dap = {
    -- Note: This requires custom setup for dap-go
    setup = function()
      require("dap-go").setup()
    end,
    adapters = {
      delve = {
        type = "server",
        port = "${port}",
        executable = {
          command = "dlv",
          args = { "dap", "-l", "127.0.0.1:${port}" },
        },
      },
    },
  },
  test_adapters = { "fredrikaverpil/neotest-golang" },
  treesitter_parsers = { "go", "gomod", "gowork", "gosum" },
  additional_plugins = {
    -- Go-specific DAP plugin
    {
      "leoluz/nvim-dap-go",
      ft = "go",
      config = function()
        require("dap-go").setup()
      end,
    },
    -- Hugo support
    {
      "phelipetls/vim-hugo",
    },
    -- Additional neotest configuration for Go
    {
      "nvim-neotest/neotest",
      optional = true,
      opts = {
        adapters = {
          ["neotest-golang"] = {
            go_test_args = { "-v", "-race", "-count=1", "-timeout=60s" },
            dap_go_enabled = true,
          },
        },
      },
    },
  },
})
