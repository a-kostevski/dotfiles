---@class LspWords
local M = {}

M.enabled = false

---Setup word highlighting
---@param opts? {enabled?: boolean}
function M.setup(opts)
  opts = opts or {}
  M.enabled = opts.enabled ~= false
end

---Enable word highlighting for a buffer using built-in document highlight
---@param client table LSP client
---@param bufnr number Buffer number
function M.on_attach(client, bufnr)
  if not M.enabled then
    return
  end

  if not client:supports_method("textDocument/documentHighlight") then
    return
  end

  local group = vim.api.nvim_create_augroup("lsp_word_" .. bufnr, { clear = true })

  vim.api.nvim_create_autocmd({ "CursorHold", "CursorHoldI" }, {
    group = group,
    buffer = bufnr,
    callback = function()
      if vim.fn.pumvisible() == 1 then
        return
      end
      local has_blink, blink = pcall(require, "blink.cmp")
      if has_blink and blink.is_visible and blink.is_visible() then
        return
      end
      vim.lsp.buf.document_highlight()
    end,
  })

  vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
    group = group,
    buffer = bufnr,
    callback = function()
      vim.lsp.buf.clear_references()
    end,
  })

  vim.api.nvim_create_autocmd("BufDelete", {
    group = group,
    buffer = bufnr,
    once = true,
    callback = function()
      pcall(vim.api.nvim_del_augroup_by_id, group)
    end,
  })
end

---Jump to next/previous document highlight
---@param count number Number of highlights to jump (negative for backwards)
---@param wrap? boolean Whether to wrap around
function M.jump(count, wrap)
  -- Use built-in LSP document highlight references from the highlight groups
  local bufnr = vim.api.nvim_get_current_buf()
  local cursor = vim.api.nvim_win_get_cursor(0)
  local cursor_row = cursor[1] - 1
  local cursor_col = cursor[2]

  -- Collect all document highlight extmarks
  local highlights = {}
  for _, ns_id in pairs(vim.api.nvim_get_namespaces()) do
    local marks = vim.api.nvim_buf_get_extmarks(bufnr, ns_id, 0, -1, { details = true })
    for _, mark in ipairs(marks) do
      local details = mark[4]
      if details and details.hl_group and details.hl_group:match("^LspReference") then
        table.insert(highlights, {
          row = mark[2],
          col = mark[3],
          end_row = details.end_row or mark[2],
          end_col = details.end_col or mark[3],
        })
      end
    end
  end

  if #highlights == 0 then
    return
  end

  table.sort(highlights, function(a, b)
    return a.row == b.row and a.col < b.col or a.row < b.row
  end)

  -- Find current position
  local current_idx
  for i, hl in ipairs(highlights) do
    if cursor_row >= hl.row and cursor_row <= hl.end_row and cursor_col >= hl.col and cursor_col <= hl.end_col then
      current_idx = i
      break
    end
  end

  local target_idx
  if current_idx then
    target_idx = current_idx + count
  else
    target_idx = count > 0 and 1 or #highlights
  end

  if wrap then
    target_idx = ((target_idx - 1) % #highlights) + 1
  else
    target_idx = math.max(1, math.min(#highlights, target_idx))
  end

  local target = highlights[target_idx]
  if target then
    vim.api.nvim_win_set_cursor(0, { target.row + 1, target.col })
  end
end

return M
