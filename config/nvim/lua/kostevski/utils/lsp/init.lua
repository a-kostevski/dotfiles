---@class LspModule Main LSP utilities interface
---@field clients table Client management utilities
---@field handlers table Custom LSP handler implementations
---@field words table Document word highlighting
---@field capabilities table Capability detection and configuration
---@field diagnostics table Diagnostic configuration
local Lsp = {}

local modules = {
  clients = "kostevski.utils.lsp.clients",
  handlers = "kostevski.utils.lsp.handlers",
  words = "kostevski.utils.lsp.words",
  capabilities = "kostevski.utils.lsp.capabilities",
  diagnostics = "kostevski.utils.lsp.diagnostics",
}

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

---Get all LSP clients for a buffer
---@param ... any Arguments forwarded to Lsp.clients.get_clients
---@return table[] clients
function Lsp.get_clients(...)
  return Lsp.clients.get_clients(...)
end

---Check if any LSP client supports a specific method for a buffer
---@param bufnr? integer Buffer number (0 or nil for current buffer)
---@param method string LSP method name
---@return boolean
function Lsp.has(bufnr, method)
  return Lsp.capabilities.has_method(bufnr, method)
end

---Get LSP clients that support formatting for a buffer
---@param bufnr? integer Buffer number
---@return table[] clients
local function get_format_clients(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  return vim.tbl_filter(function(client)
    return client:supports_method("textDocument/formatting") or client:supports_method("textDocument/rangeFormatting")
  end, vim.lsp.get_clients({ bufnr = bufnr }))
end

---Get LSP formatter configuration for integration with Utils.format registry
---@return table formatter
function Lsp.formatter()
  return {
    name = "LSP",
    primary = true,
    priority = 1,
    format = function(bufnr)
      local clients = get_format_clients(bufnr)
      if #clients > 0 then
        vim.lsp.buf.format({
          bufnr = bufnr,
          timeout_ms = 2000,
          filter = function(client)
            return vim.tbl_contains(clients, client)
          end,
        })
      end
    end,
    sources = function(bufnr)
      return vim.tbl_map(function(client)
        return client.name
      end, get_format_clients(bufnr))
    end,
  }
end

---Notify LSP clients of a file rename
---@param from string Old file path
---@param to string New file path
function Lsp.on_rename(from, to)
  Lsp.clients.rename_file(from, to)
end

-- LSP attach handlers
local on_attach_handlers = {}

---Register a callback to run when LSP attaches to a buffer
---@param fn fun(client: table, bufnr: integer)
function Lsp.on_attach(fn)
  table.insert(on_attach_handlers, fn)

  for _, client in ipairs(vim.lsp.get_clients()) do
    for bufnr in pairs(client.attached_buffers) do
      fn(client, bufnr)
    end
  end
end

---Register handler for dynamic capability registration
---@param fn fun(client: table, bufnr: integer)
function Lsp.on_dynamic_capability(fn)
  local orig_handler = vim.lsp.handlers["client/registerCapability"]

  vim.lsp.handlers["client/registerCapability"] = function(err, res, ctx)
    local ret = orig_handler(err, res, ctx)

    local client = vim.lsp.get_client_by_id(ctx.client_id)
    if client then
      for bufnr in pairs(client.attached_buffers) do
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

---Initialize all LSP utilities
function Lsp.setup()
  Lsp.handlers.setup()

  if rawget(Lsp, "words") then
    Lsp.words.setup({ enabled = true })
  end

  vim.api.nvim_create_autocmd("LspAttach", {
    group = vim.api.nvim_create_augroup("kostevski_lsp_attach", { clear = true }),
    callback = function(args)
      local bufnr = args.buf
      local client = vim.lsp.get_client_by_id(args.data.client_id)

      if client then
        for _, handler in ipairs(on_attach_handlers) do
          handler(client, bufnr)
        end
      end
    end,
  })
end

return Lsp
