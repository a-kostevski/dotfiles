local lang = require("kostevski.utils.lang")

return lang.register({
  name = "python",
  filetypes = { "python" },
  root_markers = {
    -- Python-specific
    "pyproject.toml",
    "setup.py",
    "setup.cfg",
    "requirements*.txt",
    "Pipfile",
    "Pipfile.lock",
    "poetry.lock",
    "pdm.lock",
    "pixi.lock",
    "uv.lock",
    ".python-version",
    ".venv",
    "venv",
    "pyrightconfig.json",
    "pyright.json",
    ".flake8",
    ".pylintrc",
    "pytest.ini",
    ".pytest.ini",
  },
  -- lsp_server = "basedpyright",
  formatters = {
    list = { "black", "isort" },
    tools = { "black", "isort" },
    config = {
      black = {
        prepend_args = { "--line-length", "100" },
        condition = function(self, ctx)
          return vim.fn.executable("black") == 1
        end,
      },
      isort = {
        prepend_args = { "--profile", "black" },
        condition = function(self, ctx)
          return vim.fn.executable("isort") == 1
        end,
      },
    },
  },
  linters = {
    list = { "ruff", "mypy" },
    tools = { "ruff", "mypy" },
    config = {
      ruff = {
        condition = function(ctx)
          return vim.fn.executable("ruff") == 1
        end,
      },
      mypy = {
        args = { "--ignore-missing-imports" },
        condition = function(ctx)
          return vim.fn.executable("mypy") == 1
        end,
      },
    },
  },
  dap = {
    setup = function()
      local path = require("mason-registry").get_package("debugpy"):get_install_path()
      require("dap-python").setup(path .. "/venv/bin/python")
    end,
    adapters = {
      python = {
        type = "executable",
        command = "debugpy-adapter",
      },
    },
  },
  test_adapters = { "nvim-neotest/neotest-python" },
  treesitter_parsers = { "python", "requirements" },
  settings = {
    expandtab = true,
    shiftwidth = 4,
    tabstop = 4,
    softtabstop = 4,
  },
  additional_plugins = {
    -- Python DAP plugin
    {
      "mfussenegger/nvim-dap-python",
      ft = "python",
      config = function()
        require("dap-python").setup("uv")
      end,
    },
    -- Additional neotest configuration for Python
    {
      "nvim-neotest/neotest",
      optional = true,
      opts = {
        adapters = {
          ["neotest-python"] = {
            -- runner = "pytest",
            -- python = ".venv/bin/python",
          },
        },
      },
    },
  },
})
