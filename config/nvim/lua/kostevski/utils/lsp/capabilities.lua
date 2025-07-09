---@class LspCapabilities LSP capability checking utilities
local M = {}

---Method to capability mapping
---@type table<string, string[]>
local method_capabilities = {
   ["textDocument/definition"] = { "definitionProvider" },
   ["textDocument/typeDefinition"] = { "typeDefinitionProvider" },
   ["textDocument/implementation"] = { "implementationProvider" },
   ["textDocument/references"] = { "referencesProvider" },
   ["textDocument/hover"] = { "hoverProvider" },
   ["textDocument/signatureHelp"] = { "signatureHelpProvider" },
   ["textDocument/declaration"] = { "declarationProvider" },
   ["textDocument/completion"] = { "completionProvider" },
   ["textDocument/formatting"] = { "documentFormattingProvider" },
   ["textDocument/rangeFormatting"] = { "documentRangeFormattingProvider" },
   ["textDocument/documentHighlight"] = { "documentHighlightProvider" },
   ["textDocument/documentSymbol"] = { "documentSymbolProvider" },
   ["textDocument/rename"] = { "renameProvider" },
   ["textDocument/codeAction"] = { "codeActionProvider" },
   ["textDocument/codeLens"] = { "codeLensProvider" },
   ["textDocument/documentLink"] = { "documentLinkProvider" },
   ["textDocument/documentColor"] = { "colorProvider" },
   ["textDocument/foldingRange"] = { "foldingRangeProvider" },
   ["textDocument/selectionRange"] = { "selectionRangeProvider" },
   ["textDocument/semanticTokens/full"] = { "semanticTokensProvider" },
   ["textDocument/inlayHint"] = { "inlayHintProvider" },
   ["workspace/symbol"] = { "workspaceSymbolProvider" },
}

---Get default client capabilities enhanced with completion providers
---@return table capabilities Enhanced client capabilities
function M.get_default_capabilities()
   local capabilities = vim.lsp.protocol.make_client_capabilities()

   -- Try to enhance with nvim-cmp capabilities
   local has_cmp, cmp_lsp = pcall(require, "cmp_nvim_lsp")
   if has_cmp then
      capabilities = cmp_lsp.default_capabilities(capabilities)
   end

   -- Try to enhance with blink.cmp capabilities
   local has_blink, blink = pcall(require, "blink.cmp")
   if has_blink and blink.get_lsp_capabilities then
      capabilities = vim.tbl_deep_extend("force", capabilities, blink.get_lsp_capabilities())
   end

   -- Add semantic tokens support
   capabilities.textDocument.semanticTokens = {
      multilineTokenSupport = true,
      overlappingTokenSupport = true,
   }

   -- Add modern completion capabilities
   capabilities.textDocument.completion.completionItem = {
      documentationFormat = { "markdown", "plaintext" },
      snippetSupport = true,
      preselectSupport = true,
      insertReplaceSupport = true,
      labelDetailsSupport = true,
      deprecatedSupport = true,
      commitCharactersSupport = true,
      tagSupport = { valueSet = { 1 } },
      resolveSupport = {
         properties = {
            "documentation",
            "detail",
            "additionalTextEdits",
         },
      },
   }

   -- Enhance folding capabilities
   capabilities.textDocument.foldingRange = {
      dynamicRegistration = false,
      lineFoldingOnly = true,
   }

   -- Add inlay hints support
   capabilities.textDocument.inlayHint = {
      dynamicRegistration = true,
   }

   return capabilities
end

---Check if a client has a specific capability
---@param client table LSP client
---@param capability string Capability name (supports dot notation)
---@return boolean has_capability True if client has the capability
function M.has_capability(client, capability)
   if not client.server_capabilities then
      return false
   end

   -- Direct capability check
   if client.server_capabilities[capability] ~= nil then
      return client.server_capabilities[capability] ~= false
   end

   -- Check nested capabilities
   local parts = vim.split(capability, ".", { plain = true })
   local current = client.server_capabilities

   for _, part in ipairs(parts) do
      if type(current) ~= "table" then
         return false
      end
      current = current[part]
      if current == nil then
         return false
      end
   end

   return current ~= false
end

---Check if any client for a buffer supports a method
---@param bufnr? integer Buffer number (0 or nil for current)
---@param method string|string[] LSP method(s) to check
---@return boolean has_method True if any client supports the method
function M.has_method(bufnr, method)
   bufnr = bufnr or vim.api.nvim_get_current_buf()

   -- Handle multiple methods
   if type(method) == "table" then
      for _, m in ipairs(method) do
         if M.has_method(bufnr, m) then
            return true
         end
      end
      return false
   end

   -- Normalize method name
   if not method:find("/") then
      method = "textDocument/" .. method
   end

   -- Get clients and check support
   local clients = vim.lsp.get_clients({ bufnr = bufnr })
   for _, client in ipairs(clients) do
      if client:supports_method(method) then
         return true
      end
   end

   return false
end

---Get all capabilities for a buffer
---@param bufnr? integer Buffer number (0 or nil for current)
---@return table capabilities Combined capabilities from all clients
function M.get_buffer_capabilities(bufnr)
   bufnr = bufnr or vim.api.nvim_get_current_buf()

   local capabilities = {}
   local clients = vim.lsp.get_clients({ bufnr = bufnr })

   for _, client in ipairs(clients) do
      if client.server_capabilities then
         -- Merge capabilities
         for cap, value in pairs(client.server_capabilities) do
            if value ~= false then
               capabilities[cap] = value
            end
         end
      end
   end

   return capabilities
end

---Get supported methods for a buffer
---@param bufnr? integer Buffer number (0 or nil for current)
---@return string[] methods Sorted list of supported LSP methods
function M.get_supported_methods(bufnr)
   bufnr = bufnr or vim.api.nvim_get_current_buf()

   local methods = {}
   local seen = {}

   local clients = vim.lsp.get_clients({ bufnr = bufnr })
   for _, client in ipairs(clients) do
      -- Check known method mappings
      for method, caps in pairs(method_capabilities) do
         for _, cap in ipairs(caps) do
            if M.has_capability(client, cap) and not seen[method] then
               table.insert(methods, method)
               seen[method] = true
            end
         end
      end

      -- Check dynamic capabilities using modern API
      if client.supports_method then
         for method, _ in pairs(method_capabilities) do
            if client:supports_method(method) and not seen[method] then
               table.insert(methods, method)
               seen[method] = true
            end
         end
      end
   end

   table.sort(methods)
   return methods
end

---Show capabilities information for current buffer
function M.info()
   local bufnr = vim.api.nvim_get_current_buf()
   local clients = vim.lsp.get_clients({ bufnr = bufnr })

   if #clients == 0 then
      vim.notify("No LSP clients attached to this buffer", vim.log.levels.INFO)
      return
   end

   local lines = { "# LSP Capabilities\n" }

   for _, client in ipairs(clients) do
      table.insert(lines, string.format("## %s (id: %d)\n", client.name, client.id))

      local methods = {}
      for method, _ in pairs(method_capabilities) do
         if client:supports_method(method) then
            table.insert(methods, "  - " .. method)
         end
      end

      if #methods > 0 then
         table.insert(lines, "### Supported Methods:")
         vim.list_extend(lines, methods)
      else
         table.insert(lines, "  (no known methods supported)")
      end

      table.insert(lines, "")
   end

   vim.notify(table.concat(lines, "\n"), vim.log.levels.INFO)
end

return M
