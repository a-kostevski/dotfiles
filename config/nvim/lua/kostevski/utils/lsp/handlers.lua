---@class LspHandlers
local M = {}

---Configure LSP handlers with better UI
function M.setup()
  -- Configure hover and signature help via vim.lsp.buf options
  -- These are passed at call-time in keymaps, not via deprecated vim.lsp.with()

  -- Create a reusable message handler with modern message type mapping
  local function handleMessage(_, result, ctx)
    local client = vim.lsp.get_client_by_id(ctx.client_id)
    local client_name = client and client.name or "LSP"

    -- Modern message type to log level mapping
    local level_map = {
      [vim.lsp.protocol.MessageType.Error] = vim.log.levels.ERROR,
      [vim.lsp.protocol.MessageType.Warning] = vim.log.levels.WARN,
      [vim.lsp.protocol.MessageType.Info] = vim.log.levels.INFO,
      [vim.lsp.protocol.MessageType.Log] = vim.log.levels.DEBUG,
    }

    local level = level_map[result.type] or vim.log.levels.INFO
    vim.notify(result.message, level, {
      title = client_name,
    })
  end

  -- Show message handler
  vim.lsp.handlers["window/showMessage"] = handleMessage

  -- Log message handler (usually less important)
  vim.lsp.handlers["window/logMessage"] = function(_, result, ctx)
    -- Only show errors in log messages
    if result.type == vim.lsp.protocol.MessageType.Error then
      handleMessage(_, result, ctx)
    end
  end

  -- Rename handler with summary notification
  local orig_rename = vim.lsp.handlers["textDocument/rename"]
  vim.lsp.handlers["textDocument/rename"] = function(err, result, ctx, config)
    if err then
      vim.notify("Rename failed: " .. err.message, vim.log.levels.ERROR)
      return
    end

    -- Call original handler
    orig_rename(err, result, ctx, config)

    -- Show rename summary
    local num_files = 0
    local num_changes = 0

    if result and result.changes then
      num_files = vim.tbl_count(result.changes)
      for _, edits in pairs(result.changes) do
        num_changes = num_changes + #edits
      end
    elseif result and result.documentChanges then
      num_files = #result.documentChanges
      for _, change in ipairs(result.documentChanges) do
        if change.edits then
          num_changes = num_changes + #change.edits
        end
      end
    end

    if num_files > 0 then
      vim.notify(string.format("Renamed %d occurrences in %d files", num_changes, num_files), vim.log.levels.INFO)
    end
  end
end

---Create a custom handler with error handling
---@param handler function Original handler
---@param opts? table Handler options
---@return function wrapped_handler
function M.wrap(handler, opts)
  opts = opts or {}

  return function(err, result, ctx, config)
    if err then
      local client = vim.lsp.get_client_by_id(ctx.client_id)
      local client_name = client and client.name or "LSP"

      vim.notify(string.format("%s: %s", client_name, err.message or "Unknown error"), vim.log.levels.ERROR)

      if opts.on_error then
        opts.on_error(err, ctx)
      end

      return
    end

    -- Pre-process result if needed
    if opts.filter then
      result = opts.filter(result, ctx)
    end

    -- Call original handler
    handler(err, result, ctx, config)

    -- Post-process if needed
    if opts.on_success then
      opts.on_success(result, ctx)
    end
  end
end

---Show handler information
function M.info()
  local handlers = {
    "textDocument/hover",
    "textDocument/signatureHelp",
    "textDocument/definition",
    "textDocument/references",
    "textDocument/implementation",
    "textDocument/typeDefinition",
    "textDocument/rename",
    "textDocument/codeAction",
    "textDocument/formatting",
    "textDocument/rangeFormatting",
    "textDocument/documentHighlight",
    "textDocument/documentSymbol",
    "workspace/symbol",
    "window/showMessage",
    "window/logMessage",
  }

  local lines = { "# LSP Handlers\n" }

  for _, handler in ipairs(handlers) do
    local has_handler = vim.lsp.handlers[handler] ~= nil
    local status = has_handler and "" or ""
    table.insert(lines, string.format("%s %s", status, handler))
  end

  vim.notify(table.concat(lines, "\n"), vim.log.levels.INFO)
end

-- Add toggle for verbose LSP notifications
M.verbose = false

---Toggle verbose LSP notifications
function M.toggle_verbose()
  M.verbose = not M.verbose

  if M.verbose then
    -- Show all log messages
    vim.lsp.handlers["window/logMessage"] = vim.lsp.handlers["window/showMessage"]

    -- Enable progress notifications via autocmd
    local Utils = require("kostevski.utils")
    if Utils and Utils.lsp and Utils.lsp.progress then
      Utils.lsp.progress.set_notify(true)
    end

    vim.notify("Verbose LSP notifications enabled", vim.log.levels.INFO)
  else
    -- Restore quiet log handler
    M.setup()

    -- Disable progress notifications
    local Utils = require("kostevski.utils")
    if Utils and Utils.lsp and Utils.lsp.progress then
      Utils.lsp.progress.set_notify(false)
    end

    vim.notify("Verbose LSP notifications disabled", vim.log.levels.INFO)
  end
end

-- Create user command
vim.api.nvim_create_user_command("LspVerbose", function()
  M.toggle_verbose()
end, { desc = "Toggle verbose LSP notifications" })

return M
