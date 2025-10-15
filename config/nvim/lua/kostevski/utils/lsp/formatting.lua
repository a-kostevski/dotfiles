-- ============================================================================
-- LSP Formatting - Format management and configuration
-- ============================================================================
-- This module provides comprehensive formatting control:
--   - Per-buffer format enable/disable
--   - Global autoformat settings
--   - Format-on-save autocmds
--   - Formatter preference by filetype
--   - Integration with conform.nvim
--   - Format status queries
--
-- Features:
--   - Respects buffer-local and global settings
--   - Automatic cleanup on buffer delete
--   - Preferred formatter selection
--   - Timeout control for format operations
--
-- Usage:
--   local Fmt = require("kostevski.utils.lsp.formatting")
--   Fmt.format(0)  -- Format current buffer
---   Fmt.toggle()   -- Toggle formatting
-- ============================================================================

---@class LspFormatting LSP formatting utilities
local M = {}

---Per-buffer formatting enable/disable state
---@type table<string, boolean> Maps buffer number (as string) to enabled state
local format_enabled = {}

---Preferred formatters for specific filetypes
---@type table<string, string[]> Maps filetype to list of preferred formatter names
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

---Get all LSP clients that can format a buffer
---
---Returns clients that:
---  1. Support textDocument/formatting or textDocument/rangeFormatting
---  2. Pass the optional custom filter
---  3. Match preferred formatters (if specified for the filetype)
---
---@param bufnr? number Buffer number (default: current buffer)
---@param opts? {filter?: function} Optional filter function for additional client filtering
---@return table[] clients List of LSP clients that can format the buffer
---
---@usage
---  local formatters = M.get_formatters(0)
---  for _, client in ipairs(formatters) do
---    print("Formatter:", client.name)
---  end
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

---Format a buffer using LSP or conform.nvim
---
---Formats the buffer with the following logic:
---  1. Checks if formatting is enabled (unless opts.force is true)
---  2. Finds available formatters
---  3. Prefers conform.nvim if available (unless opts.lsp_only is true)
---  4. Falls back to vim.lsp.buf.format
---
---@param bufnr? number Buffer number (default: current buffer)
---@param opts? {timeout_ms?: number, async?: boolean, force?: boolean, lsp_only?: boolean} Format options
---@return boolean success True if formatting was attempted
---
---@usage
---  M.format()  -- Format current buffer
---  M.format(0, { timeout_ms = 5000, force = true })  -- Force format with longer timeout
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

---Set up format-on-save autocmd for a buffer
---
---Called automatically during LSP attach if the client supports formatting.
---Creates a BufWritePre autocmd that formats the buffer before saving
---(if formatting is enabled). Also sets up cleanup on buffer delete.
---
---@param client table The LSP client object
---@param bufnr number The buffer number to set up formatting for
---
---@usage
---  -- Usually called automatically, but can be called manually:
---  M.on_attach(client, vim.api.nvim_get_current_buf())
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

---Display formatting status information for the current buffer
---
---Shows a notification with:
---  - Formatting enabled/disabled status
---  - Current filetype
---  - Available formatters (LSP clients)
---  - conform.nvim availability
---
---Useful for debugging formatting issues or discovering available formatters.
---
---@usage
---  :lua require("kostevski.utils.lsp.formatting").info()
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
