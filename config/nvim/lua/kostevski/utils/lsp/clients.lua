---@class LspClients LSP client management utilities
local M = {}

---@class ClientCacheEntry
---@field clients table[] LSP clients
---@field time integer Cache timestamp

---@type table<string, ClientCacheEntry> Client cache by key
local client_cache = {}

---@class GetClientsOptions
---@field method? string LSP method to filter by
---@field filter? fun(client: table): boolean Custom filter function

---Get LSP clients for a buffer with caching
---@param bufnr? integer Buffer number (0 or nil for current)
---@param opts? GetClientsOptions Additional options
---@return table[] clients Array of LSP clients
function M.get_clients(bufnr, opts)
   bufnr = bufnr or vim.api.nvim_get_current_buf()
   opts = opts or {}

   -- Check cache validity
   local cache_key = string.format("%d:%s", bufnr, opts.method or "all")
   local cached = client_cache[cache_key]
   if cached and (vim.loop.now() - cached.time) < 1000 then -- 1 second cache
      return cached.clients
   end

   -- Get clients
   local clients = vim.lsp.get_clients({ bufnr = bufnr })

   -- Filter by method support
   if opts.method then
      clients = vim.tbl_filter(function(client)
         return client:supports_method(opts.method)
      end, clients)
   end

   -- Apply custom filter
   if opts.filter then
      clients = vim.tbl_filter(opts.filter, clients)
   end

   -- Update cache
   client_cache[cache_key] = {
      clients = clients,
      time = vim.loop.now(),
   }

   return clients
end

---Get client by name for a buffer
---@param name string Client name to find
---@param bufnr? integer Buffer number (0 or nil for current)
---@return table? client LSP client or nil if not found
function M.get_client_by_name(name, bufnr)
   local clients = M.get_clients(bufnr)
   for _, client in ipairs(clients) do
      if client.name == name then
         return client
      end
   end
   return nil
end

---Check if any client supports a method
---@param method string LSP method to check
---@param bufnr? integer Buffer number (0 or nil for current)
---@return boolean supports True if any client supports the method
function M.supports_method(method, bufnr)
   local clients = M.get_clients(bufnr, { method = method })
   return #clients > 0
end

---Get combined client capabilities for a buffer
---@param bufnr? integer Buffer number (0 or nil for current)
---@return table capabilities Combined server capabilities from all clients
function M.get_capabilities(bufnr)
   local capabilities = {}
   local clients = M.get_clients(bufnr)

   for _, client in ipairs(clients) do
      if client.server_capabilities then
         capabilities = vim.tbl_deep_extend("force", capabilities, client.server_capabilities)
      end
   end

   return capabilities
end

---Clear client cache for all buffers
function M.clear_cache()
   client_cache = {}
end

---Rename file across LSP clients
---@param from string Current file path
---@param to string New file path
function M.rename_file(from, to)
   local clients = vim.lsp.get_clients()
   for _, client in ipairs(clients) do
      if client:supports_method("workspace/willRenameFiles") then
         local resp = client.request_sync("workspace/willRenameFiles", {
            files = {
               {
                  oldUri = vim.uri_from_fname(from),
                  newUri = vim.uri_from_fname(to),
               },
            },
         }, 1000)
         if resp and resp.result ~= nil then
            vim.lsp.util.apply_workspace_edit(resp.result, client.offset_encoding)
         end
      end
   end
end

-- Auto-clear cache on client changes
vim.api.nvim_create_autocmd({ "LspAttach", "LspDetach" }, {
   callback = function()
      M.clear_cache()
   end,
})

return M
