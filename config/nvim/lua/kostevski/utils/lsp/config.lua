---@class LspConfig Modern LSP configuration utilities for Neovim 0.11+
local M = {}

---Configure LSP client using vim.lsp.config API
---@param name string Server name
---@param config table Server configuration
function M.setup(name, config)
  vim.lsp.config(name, config)
  vim.lsp.enable(name)
end

---Configure global LSP settings for all clients
---@param config table Global configuration
function M.setup_global(config)
  vim.lsp.config("*", config)
end

---Load server configuration from lsp/<name>.lua file
---@param server_name string Server name
---@return table config Server configuration from file
function M.load_from_file(server_name)
  local config_path = vim.fn.stdpath("config") .. "/lsp/" .. server_name .. ".lua"
  if vim.fn.filereadable(config_path) == 1 then
    local ok, config = pcall(dofile, config_path)
    if ok and type(config) == "table" then
      return config
    end
  end
  return {}
end

---Get default server configuration with modern capabilities
---@param overrides? table Configuration overrides
---@return table config Complete server configuration
function M.get_default_config(overrides)
  overrides = overrides or {}

  local config = {
    capabilities = require("kostevski.utils.lsp.capabilities").get_default_capabilities(),
    handlers = {},
    on_attach = function(client, bufnr)
      -- Call global on_attach handlers
      local lsp = require("kostevski.utils.lsp")
      for _, handler in ipairs(lsp._on_attach_handlers or {}) do
        handler(client, bufnr)
      end
    end,
  }

  return vim.tbl_deep_extend("force", config, overrides)
end

---Check if LSP config is enabled for a server
---@param name string|table Server name or config options
---@return boolean enabled True if server is enabled
function M.is_enabled(name)
  return vim.lsp.is_enabled({ name = name })
end

---Enable or disable LSP server
---@param name string|string[] Server name(s)
---@param enable? boolean True to enable, false to disable (default: true)
function M.enable(name, enable)
  vim.lsp.enable(name, enable)
end

---Setup root markers for workspace detection
---@param markers string|string[]|string[][] Root markers configuration
---@return table config Root markers in proper format
function M.setup_root_markers(markers)
  if type(markers) == "string" then
    return { markers }
  elseif type(markers) == "table" then
    -- Check if it's already properly formatted
    if vim.tbl_islist(markers) then
      return markers
    else
      -- Convert single-level table to list
      local result = {}
      for _, marker in pairs(markers) do
        table.insert(result, marker)
      end
      return result
    end
  end

  return { ".git" } -- Default fallback
end

---Create a modern server configuration with enhanced features
---@param opts table Configuration options
---@return table config Server configuration
function M.create_config(opts)
  opts = opts or {}

  local config = M.get_default_config()

  -- Set command
  if opts.cmd then
    config.cmd = opts.cmd
  end

  -- Set filetypes
  if opts.filetypes then
    config.filetypes = opts.filetypes
  end

  -- Set root markers (modern API)
  if opts.root_markers then
    config.root_markers = M.setup_root_markers(opts.root_markers)
  end

  -- Set root_dir function (for complex logic)
  if opts.root_dir then
    config.root_dir = opts.root_dir
  end

  -- Set settings
  if opts.settings then
    config.settings = opts.settings
  end

  -- Set init_options
  if opts.init_options then
    config.init_options = opts.init_options
  end

  -- Set handlers
  if opts.handlers then
    config.handlers = opts.handlers
  end

  -- Set commands
  if opts.commands then
    config.commands = opts.commands
  end

  -- Set on_attach
  if opts.on_attach then
    local original_on_attach = config.on_attach
    config.on_attach = function(client, bufnr)
      if original_on_attach then
        original_on_attach(client, bufnr)
      end
      opts.on_attach(client, bufnr)
    end
  end

  -- Set before_init
  if opts.before_init then
    config.before_init = opts.before_init
  end

  -- Set flags
  if opts.flags then
    config.flags = opts.flags
  end

  -- Merge additional options
  if opts.extra then
    config = vim.tbl_deep_extend("force", config, opts.extra)
  end

  return config
end

---Show configuration information
function M.info()
  local lines = { "# LSP Configuration (Neovim 0.11+)\n" }

  -- API availability
  table.insert(lines, "✓ Modern vim.lsp.config API")
  table.insert(lines, "✓ Modern vim.lsp.enable API")
  table.insert(lines, "✓ Modern vim.lsp.completion API")
  table.insert(lines, "")

  -- Show configured servers
  local servers = {}
  local clients = vim.lsp.get_clients()

  for _, client in ipairs(clients) do
    if not servers[client.name] then
      servers[client.name] = {
        name = client.name,
        id = client.id,
        root_dir = client.config.root_dir,
        filetypes = client.config.filetypes,
        enabled = M.is_enabled(client.name),
      }
    end
  end

  if vim.tbl_count(servers) > 0 then
    table.insert(lines, "## Active Servers:")
    for name, info in pairs(servers) do
      local status = info.enabled and "✓" or "✗"
      table.insert(lines, string.format("%s %s (id: %d)", status, name, info.id))
      if info.root_dir then
        table.insert(lines, string.format("  Root: %s", info.root_dir))
      end
      if info.filetypes then
        table.insert(lines, string.format("  Filetypes: %s", table.concat(info.filetypes, ", ")))
      end
    end
  else
    table.insert(lines, "No active LSP servers")
  end

  vim.notify(table.concat(lines, "\n"), vim.log.levels.INFO)
end

return M
