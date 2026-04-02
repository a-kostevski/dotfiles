---@class LspCapabilities LSP capability checking and configuration utilities
local M = {}

---Get enhanced LSP client capabilities with completion support
---@return table capabilities Enhanced client capabilities for LSP servers
function M.get_default_capabilities()
  local capabilities = vim.lsp.protocol.make_client_capabilities()

  local has_blink, blink = pcall(require, "blink.cmp")
  if has_blink and blink.get_lsp_capabilities then
    capabilities = vim.tbl_deep_extend("force", capabilities, blink.get_lsp_capabilities())
  end

  capabilities.textDocument.semanticTokens = {
    multilineTokenSupport = true,
    overlappingTokenSupport = true,
  }

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

  capabilities.textDocument.foldingRange = {
    dynamicRegistration = false,
    lineFoldingOnly = true,
  }

  capabilities.textDocument.inlayHint = {
    dynamicRegistration = true,
  }

  return capabilities
end

---Check if any client for a buffer supports a method
---@param bufnr? integer Buffer number (0 or nil for current)
---@param method string|string[] LSP method(s) to check
---@return boolean has_method True if any client supports the method
function M.has_method(bufnr, method)
  bufnr = bufnr or vim.api.nvim_get_current_buf()

  if type(method) == "table" then
    for _, m in ipairs(method) do
      if M.has_method(bufnr, m) then
        return true
      end
    end
    return false
  end

  if not method:find("/") then
    method = "textDocument/" .. method
  end

  local clients = vim.lsp.get_clients({ bufnr = bufnr })
  for _, client in ipairs(clients) do
    if client:supports_method(method) then
      return true
    end
  end

  return false
end

return M
