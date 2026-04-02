---@class LspClients LSP client management utilities
local M = {}

---Get LSP clients for a buffer
---@param bufnr? integer Buffer number (0 or nil for current)
---@param opts? {method?: string, filter?: fun(client: table): boolean}
---@return table[] clients Array of LSP clients
function M.get_clients(bufnr, opts)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  opts = opts or {}

  local clients = vim.lsp.get_clients({ bufnr = bufnr })

  if opts.method then
    clients = vim.tbl_filter(function(client)
      return client:supports_method(opts.method)
    end, clients)
  end

  if opts.filter then
    clients = vim.tbl_filter(opts.filter, clients)
  end

  return clients
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

return M
