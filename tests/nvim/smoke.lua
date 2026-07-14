local function expect(condition, message)
  if not condition then
    error("nvim smoke test: " .. message)
  end
end

local function expect_equal(actual, expected, message)
  expect(actual == expected, string.format("%s (expected %s, got %s)", message, expected, actual))
end

local function plugin_spec(specs, name)
  for _, spec in ipairs(specs) do
    if spec[1] == name then
      return spec
    end
  end
  error("nvim smoke test: missing plugin spec " .. name)
end

local function apply_opts(spec)
  local opts = {}
  if type(spec.opts) == "function" then
    spec.opts(nil, opts)
  elseif type(spec.opts) == "table" then
    opts = vim.deepcopy(spec.opts)
  end
  return opts
end

expect(vim.env.DOTFILES_NVIM_SMOKE == "1", "requires DOTFILES_NVIM_SMOKE=1")
expect(vim.env.DOTFILES_NVIM_OFFLINE == "1", "requires DOTFILES_NVIM_OFFLINE=1")

-- Adapter plugin basenames are their canonical Lua module names.
apply_opts(plugin_spec(require("kostevski.plugins.lang.python"), "nvim-neotest/neotest"))
apply_opts(plugin_spec(require("kostevski.plugins.lang.javascript"), "nvim-neotest/neotest"))

local docker_specs = require("kostevski.plugins.lang.docker")
local docker = apply_opts(plugin_spec(docker_specs, "neovim/nvim-lspconfig"))
local docker_config = docker.servers.docker_language_server
expect(docker_config ~= nil, "Docker must configure docker_language_server")
expect(vim.tbl_contains(docker_config.filetypes, "dockerfile"), "Dockerfile filetype missing")
expect(vim.tbl_contains(docker_config.filetypes, "yaml.docker-compose"), "Compose filetype missing")

local docker_formatters = apply_opts(plugin_spec(docker_specs, "stevearc/conform.nvim"))
expect_equal(docker_formatters.formatters_by_ft.dockerfile[1], "dockerfmt", "Dockerfile formatter is incorrect")
expect_equal(
  docker_formatters.formatters_by_ft["yaml.docker-compose"][1],
  "yamlfmt",
  "Compose formatter is incorrect"
)

local docker_linters = apply_opts(plugin_spec(docker_specs, "mfussenegger/nvim-lint"))
expect_equal(docker_linters.linters_by_ft.dockerfile[1], "hadolint", "Dockerfile linter is incorrect")
expect(#docker_linters.linters_by_ft["yaml.docker-compose"] == 0, "Compose must not use a Dockerfile linter")

require("lspconfig")
local jsonls = vim.lsp.config.jsonls
local yamlls = vim.lsp.config.yamlls
local pyright = vim.deepcopy(vim.lsp.config.pyright)
expect(#jsonls.settings.json.schemas > 0, "jsonls has no SchemaStore schemas")
expect(next(yamlls.settings.yaml.schemas) ~= nil, "yamlls has no SchemaStore schemas")
expect(pyright.flags == nil, "pyright retains legacy flags")
pyright.root_dir = "/tmp/nvim-smoke-project"
pyright.before_init({}, pyright)
expect_equal(
  pyright.settings.python.pythonPath,
  "/tmp/nvim-smoke-project/.venv/bin/python",
  "pyright did not derive pythonPath from root_dir"
)

expect_equal(
  vim.g.python3_host_prog,
  vim.fs.joinpath(vim.fn.stdpath("data"), "nvim-venv", "bin", "python"),
  "python provider is not XDG-derived"
)
