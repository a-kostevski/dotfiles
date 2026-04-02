---@class LspDiagnostics Diagnostic configuration utilities
local M = {}

---Configure diagnostic display settings
---@param opts? table Diagnostic configuration options
function M.setup(opts)
  opts = opts or {}

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
        [vim.diagnostic.severity.ERROR] = " ",
        [vim.diagnostic.severity.WARN] = " ",
        [vim.diagnostic.severity.HINT] = " ",
        [vim.diagnostic.severity.INFO] = " ",
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

return M
