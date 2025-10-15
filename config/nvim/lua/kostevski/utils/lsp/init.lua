-- ============================================================================
-- LSP Module - Comprehensive LSP integration for Neovim 0.11+
-- ============================================================================
-- This module provides a modern, unified interface for LSP functionality with:
--   - Client management and querying
--   - Capability detection and configuration
--   - Formatting and diagnostics
--   - Progress notifications
--   - Document word highlighting
--   - Handler customization
--
-- Designed for Neovim 0.11+ with support for modern LSP APIs:
--   - vim.lsp.config for server configuration
--   - vim.lsp.enable for buffer attachment
--   - vim.lsp.completion for native completion
--
-- Usage:
--   local Lsp = require("kostevski.utils.lsp")
--   Lsp.setup()  -- Initialize all LSP utilities
--   Lsp.format() -- Format current buffer
--   if Lsp.has(0, "textDocument/formatting") then ... end
-- ============================================================================

---@class LspModule Main LSP utilities interface
---@field clients table Client management utilities
---@field handlers table Custom LSP handler implementations
---@field words table Document word highlighting
---@field formatting table LSP formatting utilities
---@field capabilities table Capability detection and configuration
---@field diagnostics table Diagnostic configuration
---@field progress table Progress notification handling
---@field config table Server configuration utilities
local Lsp = {}

-- Lazy-load sub-modules (loaded on first access)
local modules = {
  clients = "kostevski.utils.lsp.clients",
  handlers = "kostevski.utils.lsp.handlers",
  words = "kostevski.utils.lsp.words",
  formatting = "kostevski.utils.lsp.formatting",
  capabilities = "kostevski.utils.lsp.capabilities",
  diagnostics = "kostevski.utils.lsp.diagnostics",
  progress = "kostevski.utils.lsp.progress",
  config = "kostevski.utils.lsp.config",
}

-- Metatable for lazy loading
setmetatable(Lsp, {
  __index = function(self, key)
    if modules[key] then
      local ok, module = pcall(require, modules[key])
      if ok then
        rawset(self, key, module)
        return module
      else
        vim.notify(string.format("Failed to load lsp.%s: %s", key, module), vim.log.levels.ERROR)
        return nil
      end
    end
    return rawget(self, key)
  end,
})

-- ============================================================================
-- Convenience Functions - Forward commonly used functions from sub-modules
-- ============================================================================

---Get all LSP clients for a buffer
---
---Convenience wrapper for Lsp.clients.get_clients. Returns all active LSP
---clients attached to the specified buffer with optional filtering.
---
---@param ... any Arguments forwarded to Lsp.clients.get_clients
---@return table[] clients List of LSP client objects
---
---@usage
---  local clients = Lsp.get_clients(0)  -- Get clients for current buffer
function Lsp.get_clients(...)
  return Lsp.clients.get_clients(...)
end

---Check if any LSP client supports a specific method for a buffer
---
---Checks all clients attached to the buffer and returns true if at least
---one client supports the specified LSP method.
---
---@param bufnr? integer Buffer number (0 or nil for current buffer)
---@param method string LSP method name (e.g., "textDocument/formatting")
---@return boolean supported True if at least one client supports the method
---
---@usage
---  if Lsp.has(0, "textDocument/formatting") then
---    vim.lsp.buf.format()
---  end
function Lsp.has(bufnr, method)
  return Lsp.capabilities.has_method(bufnr, method)
end

---Check if any client supports a specific method (alias for has)
---@param method string LSP method name
---@param bufnr? integer Buffer number (0 or nil for current)
---@return boolean supported True if method is supported
function Lsp.supports_method(method, bufnr)
  return Lsp.capabilities.has_method(bufnr, method)
end

function Lsp.format(...)
  return Lsp.formatting.format(...)
end

---Configure LSP server using modern API
---@param name string Server name
---@param config table Server configuration
function Lsp.setup_server(name, config)
  return Lsp.config.setup(name, config)
end

---Configure global LSP settings
---@param config table Global configuration
function Lsp.setup_global(config)
  return Lsp.config.setup_global(config)
end

---Get LSP formatter configuration for integration with format utilities
---
---Returns a formatter configuration object suitable for use with custom
---formatting systems. Includes formatter name, priority, format function,
---and a function to list available formatter sources.
---
---@return table formatter Formatter configuration with name, priority, format function, and sources
---
---@usage
---  local formatter = Lsp.formatter()
---  formatter.format(0)  -- Format current buffer
---  local sources = formatter.sources(0)  -- Get formatter names
function Lsp.formatter()
  return {
    name = "LSP",
    primary = true,
    priority = 1,
    format = function(bufnr)
      Lsp.formatting.format(bufnr, { timeout_ms = 2000 })
    end,
    sources = function(bufnr)
      local clients = Lsp.formatting.get_formatters(bufnr)
      return vim.tbl_map(function(client)
        return client.name
      end, clients)
    end,
  }
end

-- LSP attach handlers
local on_attach_handlers = {}

---Register a callback to run when LSP attaches to a buffer
---
---The callback will be executed:
---  1. For all existing LSP clients and their attached buffers
---  2. Whenever a new client attaches to any buffer (via LspAttach autocmd)
---
---This is useful for setting up buffer-local keybindings, options, or
---autocmds that depend on LSP functionality.
---
---@param fn fun(client: table, bufnr: integer) Callback function receiving client and buffer number
---
---@usage
---  Lsp.on_attach(function(client, bufnr)
---    vim.keymap.set("n", "gd", vim.lsp.buf.definition, { buffer = bufnr })
---  end)
function Lsp.on_attach(fn)
  table.insert(on_attach_handlers, fn)

  -- Also register with existing clients
  for _, client in ipairs(vim.lsp.get_clients()) do
    for _, bufnr in ipairs(vim.lsp.get_buffers_by_client_id(client.id)) do
      fn(client, bufnr)
    end
  end
end

---Register handler for dynamic capability registration
---@param fn fun(client: table, bufnr: integer)
function Lsp.on_dynamic_capability(fn)
  -- Store original handler
  local orig_handler = vim.lsp.handlers["client/registerCapability"]

  vim.lsp.handlers["client/registerCapability"] = function(err, res, ctx)
    -- Call original handler
    local ret = orig_handler(err, res, ctx)

    -- Call our handler
    local client = vim.lsp.get_client_by_id(ctx.client_id)
    if client then
      for _, bufnr in ipairs(vim.lsp.get_buffers_by_client_id(client.id)) do
        fn(client, bufnr)
      end
    end

    return ret
  end
end

---Register handler for when a client supports a specific method
---@param method string LSP method name
---@param fn fun(client: table, bufnr: integer)
function Lsp.on_supports_method(method, fn)
  Lsp.on_attach(function(client, bufnr)
    if client:supports_method(method) then
      fn(client, bufnr)
    end
  end)
end

---Initialize all LSP utilities and configure handlers
---
---Sets up the LSP system by:
---  1. Initializing custom handlers (hover, signature help, etc.)
---  2. Setting up progress notifications
---  3. Configuring document word highlighting
---  4. Creating LspAttach autocmd for buffer attachment
---  5. Enabling native completion (if available in Neovim 0.11+)
---
---Should be called during Neovim initialization, typically in init.lua
---or in a plugin configuration file.
---
---@usage
---  require("kostevski.utils.lsp").setup()
function Lsp.setup()
  -- Setup handlers with modern configuration
  if rawget(Lsp, "handlers") then
    Lsp.handlers.setup()
  end

  -- Setup progress tracking
  if rawget(Lsp, "progress") then
    Lsp.progress.setup()
  end

  -- Setup document highlighting words
  if rawget(Lsp, "words") then
    Lsp.words.setup({ enabled = true })
  end

  -- Setup modern LspAttach autocmd with enhanced features
  vim.api.nvim_create_autocmd("LspAttach", {
    group = vim.api.nvim_create_augroup("kostevski_lsp_attach", { clear = true }),
    callback = function(args)
      local bufnr = args.buf
      local client = vim.lsp.get_client_by_id(args.data.client_id)

      if client then
        -- Call all registered on_attach handlers
        for _, handler in ipairs(on_attach_handlers) do
          handler(client, bufnr)
        end

        -- Setup formatting if supported
        if rawget(Lsp, "formatting") then
          Lsp.formatting.on_attach(client, bufnr)
        end

        -- Enable modern completion if supported and API is available
        if vim.lsp.completion and client:supports_method("textDocument/completion") then
          vim.lsp.completion.enable(true, client.id, bufnr, {
            autotrigger = false, -- Can be enabled per client basis
          })
        end
      end
    end,
  })
end

---Perform health check for LSP configuration and availability
---
---Verifies:
---  - Neovim 0.11+ LSP APIs (vim.lsp.config, vim.lsp.enable, vim.lsp.completion)
---  - nvim-lspconfig availability (optional)
---  - LSP submodule loading
---  - LSP config directory existence
---  - Active LSP clients and their status
---
---Integrates with Neovim's :checkhealth system.
---
---@usage
---  :checkhealth lsp_utils
function Lsp.check_health()
  local health = vim.health or require("health")
  health.report_start("LSP Utils (Neovim 0.11+)")

  -- Verify required APIs
  if vim.lsp.config then
    health.report_ok("vim.lsp.config API available")
  else
    health.report_error("vim.lsp.config API not available - requires Neovim 0.11+")
  end

  if vim.lsp.enable then
    health.report_ok("vim.lsp.enable API available")
  else
    health.report_error("vim.lsp.enable API not available - requires Neovim 0.11+")
  end

  if vim.lsp.completion then
    health.report_ok("vim.lsp.completion API available")
  else
    health.report_warn("vim.lsp.completion API not available")
  end

  -- Check nvim-lspconfig (optional in 0.11+)
  local has_lspconfig = pcall(require, "lspconfig")
  if has_lspconfig then
    health.report_info("nvim-lspconfig is installed (optional)")
  else
    health.report_info("nvim-lspconfig not installed (using native vim.lsp.config)")
  end

  -- Check sub-modules
  for name, path in pairs(modules) do
    local ok = pcall(require, path)
    if ok then
      health.report_ok(string.format("Module '%s' loaded successfully", name))
    else
      health.report_error(string.format("Failed to load module '%s'", name))
    end
  end

  -- Check LSP config directory
  local lsp_config_dir = vim.fn.stdpath("config") .. "/lsp"
  if vim.fn.isdirectory(lsp_config_dir) == 1 then
    health.report_ok("LSP config directory exists: " .. lsp_config_dir)
    local lsp_files = vim.fn.glob(lsp_config_dir .. "/*.lua", false, true)
    health.report_info(string.format("  Found %d server config files", #lsp_files))
  else
    health.report_warn("LSP config directory not found: " .. lsp_config_dir)
  end

  -- Check active servers
  local clients = vim.lsp.get_clients()
  if #clients > 0 then
    health.report_ok(string.format("Found %d active LSP clients", #clients))
    for _, client in ipairs(clients) do
      local enabled = Lsp.config.is_enabled(client.name)
      local status = enabled and "enabled" or "disabled"
      health.report_info(string.format("  - %s (id: %d, %s)", client.name, client.id, status))
    end
  else
    health.report_warn("No active LSP clients")
  end
end

return Lsp
