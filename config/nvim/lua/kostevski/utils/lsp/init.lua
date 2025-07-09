---@class LspModule
local Lsp = {}

-- Lazy-load sub-modules
local modules = {
   clients = "kostevski.utils.lsp.clients",
   handlers = "kostevski.utils.lsp.handlers",
   words = "kostevski.utils.lsp.words",
   formatting = "kostevski.utils.lsp.formatting",
   capabilities = "kostevski.utils.lsp.capabilities",
   diagnostics = "kostevski.utils.lsp.diagnostics",
   status = "kostevski.utils.lsp.status",
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

-- Forward commonly used functions from sub-modules
function Lsp.get_clients(...)
   return Lsp.clients.get_clients(...)
end

function Lsp.has(bufnr, method)
   return Lsp.capabilities.has_method(bufnr, method)
end

---Check if any client supports a specific method using modern API
---@param method string LSP method name
---@param bufnr? integer Buffer number (0 or nil for current)
---@return boolean supported True if method is supported
function Lsp.supports_method(method, bufnr)
   bufnr = bufnr or vim.api.nvim_get_current_buf()
   local clients = vim.lsp.get_clients({ bufnr = bufnr })

   for _, client in ipairs(clients) do
      if client:supports_method(method) then
         return true
      end
   end

   return false
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

---Get LSP formatter for use with format.nvim
---@return table formatter Formatter configuration
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

---Register an on_attach handler
---@param fn fun(client: table, bufnr: integer)
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

-- Setup all LSP modules
---Initialize LSP utilities and configure handlers
function Lsp.setup()
   -- Setup handlers with modern configuration
   if rawget(Lsp, "handlers") then
      Lsp.handlers.setup()
      Lsp.handlers.setup_diagnostics()
   end

   -- Setup progress tracking
   if rawget(Lsp, "progress") then
      Lsp.progress.setup()
   end

   -- Setup document highlighting words
   if rawget(Lsp, "words") then
      Lsp.words.setup({ enabled = true })
   end

   -- Setup diagnostic configuration
   if rawget(Lsp, "diagnostics") then
      Lsp.diagnostics.setup()
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

-- Health check with modern API support
function Lsp.check_health()
   local health = vim.health or require("health")
   health.report_start("LSP Utils")

   -- Check if nvim-lspconfig is installed
   local has_lspconfig = pcall(require, "lspconfig")
   if not has_lspconfig then
      health.report_error("nvim-lspconfig is not installed")
   else
      health.report_ok("nvim-lspconfig is installed")
   end

   -- Check vim.lsp.config support (Neovim 0.11+)
   if vim.lsp.config then
      health.report_ok("Modern vim.lsp.config API available")
   else
      health.report_warn("Modern vim.lsp.config API not available (requires Neovim 0.11+)")
   end

   -- Check completion API support
   if vim.lsp.completion then
      health.report_ok("Modern vim.lsp.completion API available")
   else
      health.report_warn("Modern vim.lsp.completion API not available")
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

   -- Check active servers using modern API
   local clients = vim.lsp.get_clients()
   if #clients > 0 then
      health.report_ok(string.format("Found %d active LSP clients", #clients))
      for _, client in ipairs(clients) do
         health.report_info(string.format("  - %s (id: %d)", client.name, client.id))
      end
   else
      health.report_warn("No active LSP clients")
   end
end

return Lsp
