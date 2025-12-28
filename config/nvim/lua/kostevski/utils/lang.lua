-- ============================================================================
-- Language Utilities - Unified language configuration system
-- ============================================================================
-- This module provides a declarative way to register language support with
-- automatic integration of LSP servers, formatters, linters, debuggers,
-- test runners, and treesitter parsers.
--
-- Benefits:
--   - Single source of truth for language configuration
--   - Automatic plugin configuration (lazy.nvim compatible)
--   - Simplified Mason package management
--   - Built-in support for both Neovim 0.10 and 0.11+
--
-- Usage:
--   local Lang = require("kostevski.utils.lang")
--   return Lang.register({
--     name = "python",
--     filetypes = { "python" },
--     lsp_server = "basedpyright",
--     formatters = { list = { "black" }, tools = { "black" } },
--     -- ... more config
--   })
-- ============================================================================

---@class LangUtils Language configuration utilities
local M = {}

-- Default configuration when no languages.lua exists
local DEFAULT_CONFIG = {
  enabled = { "lua" },
  overrides = {},
}

---Load and cache language configuration
---@return {enabled: string|string[], overrides: table}
function M.get_config()
  if M._config then
    return M._config
  end

  local ok, config = pcall(require, "kostevski.config.languages")
  if not ok or type(config) ~= "table" then
    config = vim.deepcopy(DEFAULT_CONFIG)
  end

  -- Ensure required fields exist
  config.enabled = config.enabled or DEFAULT_CONFIG.enabled
  config.overrides = config.overrides or {}

  M._config = config
  return config
end

---Check if a language is enabled
---@param name string Language name
---@return boolean
function M.is_enabled(name)
  local config = M.get_config()

  if config.enabled == "all" then
    return true
  end

  if type(config.enabled) == "table" then
    return vim.tbl_contains(config.enabled, name)
  end

  return false
end

---Get configuration overrides for a language
---@param name string Language name
---@return table
function M.get_overrides(name)
  local config = M.get_config()
  return config.overrides and config.overrides[name] or {}
end

---Get list of available language configurations
---@return string[]
function M.get_available()
  if M._available then
    return M._available
  end

  local lang_dir = vim.fn.stdpath("config") .. "/lua/kostevski/plugins/lang"
  local files = vim.fn.glob(lang_dir .. "/*.lua", false, true)

  M._available = {}
  for _, file in ipairs(files) do
    local name = vim.fn.fnamemodify(file, ":t:r")
    table.insert(M._available, name)
  end

  return M._available
end

---Validate configuration and warn about unknown languages
function M.validate()
  local config = M.get_config()

  if config.enabled == "all" then
    return
  end

  if type(config.enabled) ~= "table" then
    return
  end

  local available = M.get_available()
  for _, name in ipairs(config.enabled) do
    if not vim.tbl_contains(available, name) then
      vim.notify(
        string.format("[lang] '%s' is enabled but no config exists in plugins/lang/", name),
        vim.log.levels.WARN
      )
    end
  end
end

---@class LanguageDefinition Complete language configuration specification
---@field name string Language identifier (e.g., "go", "python", "typescript")
---@field filetypes string[] Vim filetypes this language applies to
---@field root_markers? (string|string[])[] Root markers for LSP and project detection (Neovim 0.11+)
---@field lsp_server? string|{name:string, config:table} LSP server name or detailed config
---@field formatters? {list:string[], tools:string[], config?:table} Formatter configuration for conform.nvim
---@field linters? {list:string[], tools:string[], config?:table} Linter configuration for nvim-lint
---@field dap? {adapters:table, configurations:table} Debug Adapter Protocol configuration
---@field test_adapters? string[] Neotest adapter plugin names (e.g., "nvim-neotest/neotest-python")
---@field treesitter_parsers? string[] Treesitter parser names to install
---@field mason_packages? string[] Additional Mason packages (tools, linters, etc.)
---@field settings? table FileType-specific vim options (e.g., {expandtab=true, shiftwidth=4})
---@field additional_plugins? table[] Extra lazy.nvim plugin specifications

---Register a complete language configuration and return plugin specs
---
---This is the main entry point for language configuration. Takes a language
---definition and generates all necessary lazy.nvim plugin specifications for:
---  - LSP server configuration and installation
---  - Formatter setup (conform.nvim)
---  - Linter setup (nvim-lint)
---  - Debug adapter configuration (nvim-dap)
---  - Test adapter setup (neotest)
---  - Treesitter parser installation
---  - Mason package management
---  - FileType-specific settings
---
---@param def LanguageDefinition Complete language configuration
---@return table[] plugin_specs Array of lazy.nvim plugin specifications
---
---@usage
---  -- In lua/kostevski/plugins/lang/python.lua
---  local Lang = require("kostevski.utils.lang")
---  return Lang.register({
---    name = "python",
---    filetypes = { "python" },
---    lsp_server = "basedpyright",
---    formatters = { list = { "ruff_format" }, tools = { "ruff" } },
---  })
function M.register(def)
  local specs = {}

  -- Check if language is enabled
  if not M.is_enabled(def.name) then
    return {}
  end

  -- Merge any overrides from config
  local overrides = M.get_overrides(def.name)
  if next(overrides) then
    def = vim.tbl_deep_extend("force", def, overrides)
  end

  -- Support both root_patterns (legacy) and root_markers (0.11+)
  local root_markers = def.root_markers or def.root_markers
  if root_markers then
    require("kostevski.utils.root").add_patterns(def.name, root_markers)
  end

  -- Create FileType autocmd if settings are provided
  if def.settings then
    vim.api.nvim_create_autocmd("FileType", {
      pattern = def.filetypes,
      callback = function()
        for key, value in pairs(def.settings) do
          if key:match("^[A-Za-z]+$") then
            vim.opt_local[key] = value
          else
            vim.notify(string.format("Invalid setting key '%s' for language '%s'", key, def.name), vim.log.levels.WARN)
          end
        end
      end,
    })
  end

  -- Mason packages installation
  local mason_packages = Utils.flatten({
    def.mason_packages or {},
    def.formatters and def.formatters.tools or {},
    def.linters and def.linters.tools or {},
  })

  if #mason_packages > 0 then
    table.insert(specs, {
      "mason.nvim",
      optional = true,
      opts_extend = { "ensure_installed" },
      opts = {
        ensure_installed = mason_packages,
      },
    })
  end

  -- Formatter configuration
  if def.formatters then
    table.insert(specs, {
      "stevearc/conform.nvim",
      optional = true,
      opts = function(_, opts)
        opts = opts or {}
        opts.formatters_by_ft = opts.formatters_by_ft or {}
        opts.formatters = opts.formatters or {}

        -- Set formatters for filetypes
        for _, ft in ipairs(def.filetypes) do
          opts.formatters_by_ft[ft] = def.formatters.list
        end

        -- Add formatter-specific configurations
        if def.formatters.config then
          opts.formatters = vim.tbl_deep_extend("force", opts.formatters, def.formatters.config)
        end
      end,
    })
  end

  -- Linter configuration
  if def.linters then
    table.insert(specs, {
      "mfussenegger/nvim-lint",
      optional = true,
      opts = function(_, opts)
        opts = opts or {}
        opts.linters_by_ft = opts.linters_by_ft or {}
        opts.linters = opts.linters or {}

        -- Set linters for filetypes
        for _, ft in ipairs(def.filetypes) do
          opts.linters_by_ft[ft] = def.linters.list or {}
        end

        -- Add linter-specific configurations
        if def.linters.config then
          opts.linters = vim.tbl_deep_extend("force", opts.linters, def.linters.config)
        end
      end,
    })
  end
  -- DAP configuration
  if def.dap then
    table.insert(specs, {
      "mfussenegger/nvim-dap",
      optional = true,
      config = function()
        local dap = require("dap")
        -- Apply DAP configurations
        for key, value in pairs(def.dap) do
          if key == "adapters" then
            for adapter_name, adapter_config in pairs(value) do
              dap.adapters[adapter_name] = adapter_config
            end
          elseif key == "configurations" then
            for ft, configs in pairs(value) do
              dap.configurations[ft] = configs
            end
          end
        end
      end,
    })
  end

  -- Neotest configuration
  if def.test_adapters and #def.test_adapters > 0 then
    table.insert(specs, {
      "nvim-neotest/neotest",
      optional = true,
      dependencies = def.test_adapters,
      opts = function(_, opts)
        opts = opts or {}
        opts.adapters = opts.adapters or {}
        for _, adapter in ipairs(def.test_adapters) do
          -- Extract adapter name from plugin spec
          local adapter_name = adapter:match("([^/]+)$"):gsub("^neotest%-", "")
          table.insert(opts.adapters, require(adapter_name))
        end
      end,
    })
  end

  -- Treesitter parsers
  if def.treesitter_parsers and #def.treesitter_parsers > 0 then
    table.insert(specs, {
      "nvim-treesitter/nvim-treesitter",
      opts = function(_, opts)
        if type(opts.ensure_installed) == "table" then
          vim.list_extend(opts.ensure_installed, def.treesitter_parsers)
        end
      end,
    })
  end

  -- LSP server configuration
  if def.lsp_server then
    -- Add LSP server to lspconfig servers
    table.insert(specs, {
      "neovim/nvim-lspconfig",
      opts = function(_, opts)
        opts.servers = opts.servers or {}

        -- Build base server config
        local server_config = {
          filetypes = def.filetypes,
        }

        -- Add root_markers for Neovim 0.11+
        if root_markers then
          server_config.root_markers = root_markers
        end

        if type(def.lsp_server) == "string" then
          opts.servers[def.lsp_server] = server_config
        elseif type(def.lsp_server) == "table" then
          opts.servers[def.lsp_server.name] = vim.tbl_deep_extend("force", server_config, def.lsp_server.config or {})
        end
      end,
    })

    -- Ensure LSP server is installed via Mason
    if type(def.lsp_server) == "string" then
      table.insert(specs, {
        "mason-lspconfig.nvim",
        optional = true,
        opts_extend = { "ensure_installed" },
        opts = {
          ensure_installed = { def.lsp_server },
        },
      })
    elseif type(def.lsp_server) == "table" and def.lsp_server.name then
      table.insert(specs, {
        "mason-lspconfig.nvim",
        optional = true,
        opts_extend = { "ensure_installed" },
        opts = {
          ensure_installed = { def.lsp_server.name },
        },
      })
    end
  end

  -- Add any additional plugins
  if def.additional_plugins then
    vim.list_extend(specs, def.additional_plugins)
  end
  return specs
end

---Create a language configuration from built-in templates
---
---Provides pre-configured language definitions for common languages.
---Supports custom overrides to adapt the template to specific needs.
---
---Supported templates:
---  - go: Go with gopls, goimports, gofumpt, golangci-lint
---  - python: Python with basedpyright, ruff
---  - rust: Rust with rust_analyzer, rustfmt
---  - typescript: TypeScript/JavaScript with ts_ls, prettier, eslint
---  - lua: Lua with lua_ls, stylua
---  - bash: Bash with bashls, shfmt, shellcheck
---  - shell: Shell (zsh, sh) with bashls, shfmt, shellcheck
---  - makefile: Makefile with autotools_ls, checkmake
---
---@param name string Template name (e.g., "go", "python", "rust")
---@param opts? table Optional overrides to merge with the template
---@return LanguageDefinition config The configured language definition
---
---@usage
---  -- Use Python template with custom settings
---  local def = Lang.create_simple("python", {
---    lsp_server = "pyright",  -- Override LSP server
---    settings = { shiftwidth = 2 }  -- Custom indent
---  })
function M.create_simple(name, opts)
  local defaults = {
    lua = {
      name = "lua",
      filetypes = { "lua" },
      lsp_server = {
        name = "lua_ls",
        config = {
          settings = {
            Lua = {
              workspace = {
                checkThirdParty = false,
              },
              completion = {
                callSnippet = "Replace",
              },
            },
          },
        },
      },
      formatters = {
        list = { "stylua" },
        tools = { "stylua" },
      },
      treesitter_parsers = { "lua", "luadoc" },
      root_patterns = { "stylua.toml", ".stylua.toml", ".git" },
    },
    bash = {
      name = "bash",
      filetypes = { "sh", "bash" },
      lsp_server = "bashls",
      formatters = {
        list = { "shfmt" },
        tools = { "shfmt", "beautysh" },
      },
      linters = {
        list = { "shellcheck" },
        tools = { "shellcheck" },
      },
      treesitter_parsers = { "bash" },
      root_patterns = { ".shellcheckrc", ".bashrc", ".git" },
      settings = {
        expandtab = true,
        shiftwidth = 2,
        tabstop = 2,
        softtabstop = 2,
      },
    },
    shell = {
      name = "shell",
      filetypes = { "zsh", "sh" },
      lsp_server = "bashls",
      formatters = {
        list = { "shfmt" },
        tools = { "shfmt", "beautysh" },
      },
      linters = {
        list = { "shellcheck" },
        tools = { "shellcheck" },
      },
      treesitter_parsers = { "bash" },
      root_patterns = { ".zshrc", ".shellcheckrc", ".git" },
      settings = {
        expandtab = true,
        shiftwidth = 2,
        tabstop = 2,
        softtabstop = 2,
      },
    },
  }

  local base = defaults[name] or { name = name, filetypes = { name } }
  return vim.tbl_deep_extend("force", base, opts or {})
end

-- Validate configuration after startup
vim.defer_fn(function()
  M.validate()
end, 100)

return M
