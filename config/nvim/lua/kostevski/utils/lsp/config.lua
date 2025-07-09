---@class LspConfig Modern LSP configuration utilities
local M = {}

---Configure LSP client using modern vim.lsp.config API
---@param name string Server name
---@param config table Server configuration
function M.setup(name, config)
   -- Use modern vim.lsp.config if available (Neovim 0.11+)
   if vim.lsp.config then
      vim.lsp.config(name, config)
      vim.lsp.enable(name)
   else
      -- Fallback to traditional lspconfig for older versions
      local ok, lspconfig = pcall(require, "lspconfig")
      if ok and lspconfig[name] then
         lspconfig[name].setup(config)
      else
         vim.notify(string.format("Failed to configure %s: lspconfig not available", name), vim.log.levels.ERROR)
      end
   end
end

---Configure global LSP settings for all clients
---@param config table Global configuration
function M.setup_global(config)
   if vim.lsp.config then
      vim.lsp.config("*", config)
   else
      -- For older versions, store config for manual application
      M._global_config = config
   end
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

   -- Apply manual global config for older versions
   if M._global_config and not vim.lsp.config then
      config = vim.tbl_deep_extend("force", config, M._global_config)
   end

   return vim.tbl_deep_extend("force", config, overrides)
end

---Check if LSP config is enabled for a server
---@param name string Server name
---@return boolean enabled True if server is enabled
function M.is_enabled(name)
   if vim.lsp.is_enabled then
      return vim.lsp.is_enabled(name)
   else
      -- Fallback check for older versions
      local clients = vim.lsp.get_clients()
      for _, client in ipairs(clients) do
         if client.name == name then
            return true
         end
      end
      return false
   end
end

---Enable or disable LSP server
---@param name string Server name
---@param enable? boolean True to enable, false to disable (default: true)
function M.enable(name, enable)
   enable = enable ~= false

   if vim.lsp.enable then
      vim.lsp.enable(name, enable)
   else
      if enable then
         vim.notify(string.format("Cannot enable %s: modern LSP API not available", name), vim.log.levels.WARN)
      else
         -- Manual disable for older versions
         local clients = vim.lsp.get_clients()
         for _, client in ipairs(clients) do
            if client.name == name then
               client.stop()
            end
         end
      end
   end
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

   -- Set root markers
   if opts.root_markers then
      config.root_markers = M.setup_root_markers(opts.root_markers)
   end

   -- Set settings
   if opts.settings then
      config.settings = opts.settings
   end

   -- Merge additional options
   if opts.extra then
      config = vim.tbl_deep_extend("force", config, opts.extra)
   end

   return config
end

---Show configuration information
function M.info()
   local lines = { "# LSP Configuration\n" }

   -- Check API availability
   if vim.lsp.config then
      table.insert(lines, "✓ Modern vim.lsp.config API available")
   else
      table.insert(lines, "⚠ Using legacy lspconfig (consider upgrading to Neovim 0.11+)")
   end

   if vim.lsp.enable then
      table.insert(lines, "✓ Modern vim.lsp.enable API available")
   else
      table.insert(lines, "⚠ Legacy client management")
   end

   if vim.lsp.completion then
      table.insert(lines, "✓ Modern vim.lsp.completion API available")
   else
      table.insert(lines, "⚠ Legacy completion handling")
   end

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
         }
      end
   end

   if vim.tbl_count(servers) > 0 then
      table.insert(lines, "## Active Servers:")
      for name, info in pairs(servers) do
         table.insert(lines, string.format("- %s (id: %d)", name, info.id))
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
