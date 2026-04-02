---@class LspHandlers
local M = {}

---Configure LSP handlers with better UI
function M.setup()
  local function handleMessage(_, result, ctx)
    local client = vim.lsp.get_client_by_id(ctx.client_id)
    local client_name = client and client.name or "LSP"

    local level_map = {
      [vim.lsp.protocol.MessageType.Error] = vim.log.levels.ERROR,
      [vim.lsp.protocol.MessageType.Warning] = vim.log.levels.WARN,
      [vim.lsp.protocol.MessageType.Info] = vim.log.levels.INFO,
      [vim.lsp.protocol.MessageType.Log] = vim.log.levels.DEBUG,
    }

    local level = level_map[result.type] or vim.log.levels.INFO
    vim.notify(result.message, level, { title = client_name })
  end

  vim.lsp.handlers["window/showMessage"] = handleMessage

  vim.lsp.handlers["window/logMessage"] = function(_, result, ctx)
    if result.type == vim.lsp.protocol.MessageType.Error then
      handleMessage(_, result, ctx)
    end
  end

  local orig_rename = vim.lsp.handlers["textDocument/rename"]
  vim.lsp.handlers["textDocument/rename"] = function(err, result, ctx, config)
    if err then
      vim.notify("Rename failed: " .. err.message, vim.log.levels.ERROR)
      return
    end

    orig_rename(err, result, ctx, config)

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

return M
