-- ============================================================================
-- LSP Diagnostics - Modern diagnostic configuration for Neovim 0.11+
-- ============================================================================
-- This module provides a centralized diagnostic configuration system:
--   - Consistent diagnostic signs (icons)
--   - Virtual text configuration
--   - Floating window settings
--   - Severity sorting and filtering
--   - Update behavior control
--
-- Features:
--   - Modern Neovim 0.11+ diagnostic API support
--   - Customizable icons and styling
--   - Single source of truth for diagnostic config
--   - Info command for debugging
--
-- Usage:
--   local Diag = require("kostevski.utils.lsp.diagnostics")
--   Diag.setup({ virtual_text = { spacing = 4 } })
--   Diag.info()  -- Show current config
-- ============================================================================

---@class LspDiagnostics Modern diagnostic configuration utilities
local M = {}

---Default diagnostic sign icons
---Uses Nerd Font icons for better visual distinction
---@type table<string, string>
M.signs = {
  Error = " ",
  Warn = " ",
  Hint = " ",
  Info = " ",
}

---Configure diagnostic display settings
---
---Sets up diagnostic signs, virtual text, floating windows, and behavior.
---Acts as a single source of truth for all diagnostic configuration.
---Supports all vim.diagnostic.config() options plus custom sign configuration.
---
---@param opts? {underline?: boolean, update_in_insert?: boolean, virtual_text?: table|boolean, severity_sort?: boolean, signs?: table, float?: table} Diagnostic configuration options
---
---@usage
---  -- Minimal setup with defaults
---  M.setup()
---
---  -- Custom configuration
---  M.setup({
---    virtual_text = { spacing = 4, prefix = "●" },
---    signs = { text = { [vim.diagnostic.severity.ERROR] = "✗" } },
---    float = { border = "rounded" },
---  })
function M.setup(opts)
  opts = opts or {}

  -- Get icons from opts or defaults
  local icons = opts.signs and opts.signs.text or M.signs

  -- Configure diagnostic signs
  for type, icon in pairs(icons) do
    local hl = "DiagnosticSign" .. type
    vim.fn.sign_define(hl, { text = icon, texthl = hl, numhl = hl })
  end

  -- Modern Neovim 0.11+ diagnostic configuration
  local config = {
    underline = opts.underline ~= false,
    update_in_insert = opts.update_in_insert or false,
    virtual_text = opts.virtual_text or {
      spacing = 4,
      source = "if_many",
      prefix = "●",
    },
    severity_sort = opts.severity_sort ~= false,
    signs = opts.signs or {
      text = {
        [vim.diagnostic.severity.ERROR] = icons.Error or M.signs.Error,
        [vim.diagnostic.severity.WARN] = icons.Warn or M.signs.Warn,
        [vim.diagnostic.severity.HINT] = icons.Hint or M.signs.Hint,
        [vim.diagnostic.severity.INFO] = icons.Info or M.signs.Info,
      },
    },
    float = opts.float or {
      focusable = false,
      style = "minimal",
      border = "rounded",
      source = "if_many",
      header = "",
      prefix = "",
    },
  }

  vim.diagnostic.config(config)
end

---Retrieve the current diagnostic configuration
---
---Returns the active diagnostic configuration from vim.diagnostic.config().
---Useful for inspecting current settings or conditionally modifying config.
---
---@return table config Current diagnostic configuration table
---
---@usage
---  local config = M.get_config()
---  print("Virtual text enabled:", config.virtual_text ~= false)
function M.get_config()
  return vim.diagnostic.config()
end

---Display current diagnostic configuration information
---
---Shows a notification with the current state of:
---  - Virtual text (enabled/disabled)
---  - Signs (enabled/disabled)
---  - Underline (enabled/disabled)
---  - Severity sort (enabled/disabled)
---  - Update in insert mode (enabled/disabled)
---
---Useful for debugging diagnostic configuration issues.
---
---@usage
---  :lua require("kostevski.utils.lsp.diagnostics").info()
function M.info()
  local config = M.get_config()
  local lines = { "# Diagnostic Configuration\n" }

  table.insert(lines, string.format("Virtual Text: %s", config.virtual_text and "enabled" or "disabled"))
  table.insert(lines, string.format("Signs: %s", config.signs and "enabled" or "disabled"))
  table.insert(lines, string.format("Underline: %s", config.underline and "enabled" or "disabled"))
  table.insert(lines, string.format("Severity Sort: %s", config.severity_sort and "enabled" or "disabled"))
  table.insert(lines, string.format("Update in Insert: %s", config.update_in_insert and "enabled" or "disabled"))

  vim.notify(table.concat(lines, "\n"), vim.log.levels.INFO)
end

return M
