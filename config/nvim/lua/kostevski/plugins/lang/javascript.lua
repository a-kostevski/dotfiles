local lang = require("kostevski.utils.lang")

return lang.register({
  name = "javascript",
  filetypes = { "javascript", "javascriptreact", "js", "jsx" },
  native_lsp = true, -- lsp/ts_ls.lua handles LSP config
  root_markers = {
    "package.json",
    "tsconfig.json",
    ".eslintrc.js",
    ".eslintrc.json",
    "webpack.config.js",
    "vite.config.js",
    "next.config.js",
    "nuxt.config.js",
    ".git",
  },
  lsp_server = "ts_ls",
  formatters = {
    list = { "prettier", "biome" },
    tools = {
      "prettier",
      "biome",
    },
    config = {
      prettier = {
        extra_args = { "--no-semi", "--single-quote", "--jsx-single-quote" },
      },
    },
  },
  linters = {
    list = { "eslint" },
    tools = { "eslint_d" },
  },
  dap = {
    adapters = { "node-debug2-adapter" },
    setup = function()
      local dap = require("dap")
      dap.adapters.node2 = {
        type = "executable",
        command = "node",
        args = { vim.fn.stdpath("data") .. "/mason/packages/node-debug2-adapter/out/src/nodeDebug.js" },
      }
      dap.configurations.javascript = {
        {
          name = "Launch",
          type = "node2",
          request = "launch",
          program = "${file}",
          cwd = vim.fn.getcwd(),
          sourceMaps = true,
          protocol = "inspector",
          console = "integratedTerminal",
        },
        {
          name = "Attach to process",
          type = "node2",
          request = "attach",
          processId = require("dap.utils").pick_process,
        },
      }
    end,
  },
  test_adapters = { "nvim-neotest/neotest-jest" },
  treesitter_parsers = { "javascript", "jsdoc" },
  settings = {
    expandtab = true,
    shiftwidth = 2,
    tabstop = 2,
    softtabstop = 2,
  },
  additional_plugins = {
    {
      "windwp/nvim-ts-autotag",
      opts = {
        opts = {
          enable_close = true,
          enable_rename = true,
          enable_close_on_slash = false,
        },
        per_filetype = {
          ["javascript"] = {
            enable_close = false,
          },
          ["javascriptreact"] = {
            enable_close = true,
          },
        },
      },
    },
    {
      "nvim-treesitter/nvim-treesitter-context",
      opts = {
        enable = true,
        patterns = {
          javascript = {
            "class_declaration",
            "method_definition",
            "arrow_function",
            "function_declaration",
            "function_expression",
          },
        },
      },
    },
  },
})
