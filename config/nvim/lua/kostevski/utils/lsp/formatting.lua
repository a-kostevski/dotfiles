---@class LspFormatting
local M = {}

---@type table<string, boolean> Track which buffers have formatting enabled
local format_enabled = {}

---@type table<string, string[]> Filetype to preferred formatters mapping
local preferred_formatters = {}

---Configure formatting preferences
---@param opts? {preferred?: table<string, string[]>}
function M.setup(opts)
   opts = opts or {}
   if opts.preferred then
      preferred_formatters = opts.preferred
   end
end

---Check if formatting is enabled for a buffer
---@param bufnr? number Buffer number
---@return boolean
function M.is_enabled(bufnr)
   bufnr = bufnr or vim.api.nvim_get_current_buf()

   -- Check buffer-local setting first
   local buf_enabled = format_enabled[tostring(bufnr)]
   if buf_enabled ~= nil then
      return buf_enabled
   end

   -- Fall back to global setting
   return vim.g.autoformat ~= false
end

---Enable or disable formatting for a buffer
---@param bufnr? number Buffer number
---@param enabled boolean Whether to enable formatting
function M.set_enabled(bufnr, enabled)
   bufnr = bufnr or vim.api.nvim_get_current_buf()
   format_enabled[tostring(bufnr)] = enabled
end

---Toggle formatting for a buffer
---@param bufnr? number Buffer number
function M.toggle(bufnr)
   bufnr = bufnr or vim.api.nvim_get_current_buf()
   M.set_enabled(bufnr, not M.is_enabled(bufnr))

   local state = M.is_enabled(bufnr) and "enabled" or "disabled"
   vim.notify(string.format("Formatting %s for buffer %d", state, bufnr), vim.log.levels.INFO)
end

---Get formatting clients for a buffer
---@param bufnr? number Buffer number
---@param opts? {filter?: function} Additional options
---@return table[] clients
function M.get_formatters(bufnr, opts)
   bufnr = bufnr or vim.api.nvim_get_current_buf()
   opts = opts or {}

   local Utils = require("kostevski.utils")
   local clients = Utils.lsp.get_clients(bufnr, {
      filter = function(client)
         -- Check if client supports formatting
         if
            not client:supports_method("textDocument/formatting")
            and not client:supports_method("textDocument/rangeFormatting")
         then
            return false
         end

         -- Apply custom filter
         if opts.filter and not opts.filter(client) then
            return false
         end

         -- Check preferred formatters
         local ft = vim.bo[bufnr].filetype
         local preferred = preferred_formatters[ft]
         if preferred and not vim.tbl_contains(preferred, client.name) then
            return false
         end

         return true
      end,
   })

   return clients
end

---Format a buffer using LSP
---@param bufnr? number Buffer number
---@param opts? table Format options
---@return boolean success
function M.format(bufnr, opts)
   bufnr = bufnr or vim.api.nvim_get_current_buf()
   opts = vim.tbl_deep_extend("force", {
      timeout_ms = 2000,
      async = false,
   }, opts or {})

   -- Check if formatting is enabled
   if not opts.force and not M.is_enabled(bufnr) then
      return false
   end

   -- Get formatters
   local clients = M.get_formatters(bufnr, opts)
   if #clients == 0 then
      if opts.force then
         vim.notify("No LSP formatters available", vim.log.levels.WARN)
      end
      return false
   end

   -- Prefer conform.nvim if available
   local has_conform, conform = pcall(require, "conform")
   if has_conform and not opts.lsp_only then
      return conform.format(vim.tbl_extend("force", opts, { bufnr = bufnr }))
   end

   -- Use LSP formatting
   opts.bufnr = bufnr
   opts.filter = function(client)
      return vim.tbl_contains(clients, client)
   end

   vim.lsp.buf.format(opts)
   return true
end

---Create format on save autocmd
---@param bufnr number Buffer number
---@param client table LSP client
function M.on_attach(client, bufnr)
   if
      not client:supports_method("textDocument/formatting")
      and not client:supports_method("textDocument/rangeFormatting")
   then
      return
   end

   -- Create format on save autocmd for this buffer
   local group = vim.api.nvim_create_augroup("lsp_format_" .. bufnr, { clear = true })

   vim.api.nvim_create_autocmd("BufWritePre", {
      group = group,
      buffer = bufnr,
      callback = function()
         if M.is_enabled(bufnr) then
            M.format(bufnr, { timeout_ms = 1000 })
         end
      end,
   })

   -- Clean up on buffer delete
   vim.api.nvim_create_autocmd("BufDelete", {
      group = group,
      buffer = bufnr,
      callback = function()
         format_enabled[tostring(bufnr)] = nil
      end,
   })
end

---Get formatting status information
---@param bufnr? number Buffer number
---@return table status
function M.get_status(bufnr)
   bufnr = bufnr or vim.api.nvim_get_current_buf()

   local formatters = M.get_formatters(bufnr)
   local formatter_names = vim.tbl_map(function(c)
      return c.name
   end, formatters)

   -- Check for conform.nvim
   local has_conform = pcall(require, "conform")

   return {
      enabled = M.is_enabled(bufnr),
      formatters = formatter_names,
      has_conform = has_conform,
      filetype = vim.bo[bufnr].filetype,
   }
end

---Show formatting information for current buffer
function M.info()
   local status = M.get_status()

   local lines = {
      "# Formatting Status",
      "",
      string.format("Enabled: %s", status.enabled and "✓" or "✗"),
      string.format("Filetype: %s", status.filetype),
      "",
      "## Available Formatters:",
   }

   if #status.formatters > 0 then
      for _, formatter in ipairs(status.formatters) do
         table.insert(lines, string.format("  - %s", formatter))
      end
   else
      table.insert(lines, "  (none)")
   end

   if status.has_conform then
      table.insert(lines, "")
      table.insert(lines, "Note: conform.nvim is available and will be preferred")
   end

   vim.notify(table.concat(lines, "\n"), vim.log.levels.INFO)
end

return M
