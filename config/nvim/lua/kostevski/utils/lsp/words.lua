---@class LspWords
local M = {}

-- Configuration
M.enabled = false
M.ns = vim.api.nvim_create_namespace("lsp_word_highlights")

---@type table<number, boolean> Track buffers with word highlighting
local active_buffers = {}

---Setup word highlighting
---@param opts? {enabled?: boolean}
function M.setup(opts)
   opts = opts or {}
   M.enabled = opts.enabled ~= false

   if not M.enabled then
      return
   end

   -- Override the default handler to add our logic
   local orig_handler = vim.lsp.handlers["textDocument/documentHighlight"]
   vim.lsp.handlers["textDocument/documentHighlight"] = function(err, result, ctx, config)
      if not vim.api.nvim_buf_is_loaded(ctx.bufnr) then
         return
      end

      -- Clear existing highlights
      vim.lsp.buf.clear_references()

      -- Call original handler
      if orig_handler then
         orig_handler(err, result, ctx, config)
      end
   end
end

---Enable word highlighting for a buffer
---@param client table LSP client
---@param bufnr number Buffer number
function M.on_attach(client, bufnr)
   if not M.enabled then
      return
   end

   if not client:supports_method("textDocument/documentHighlight") then
      return
   end

   if active_buffers[bufnr] then
      return -- Already set up
   end

   active_buffers[bufnr] = true

   -- Create autocmds for this buffer
   local group = vim.api.nvim_create_augroup("lsp_word_" .. bufnr, { clear = true })

   vim.api.nvim_create_autocmd({ "CursorHold", "CursorHoldI" }, {
      group = group,
      buffer = bufnr,
      callback = function()
         -- Don't highlight if completion menu is visible
         if vim.fn.pumvisible() == 1 then
            return
         end

         -- Check for blink.cmp
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

   -- Clean up on buffer delete
   vim.api.nvim_create_autocmd("BufDelete", {
      group = group,
      buffer = bufnr,
      callback = function()
         active_buffers[bufnr] = nil
      end,
   })
end

---Get current word highlights
---@param bufnr? number Buffer number
---@return table[] highlights List of highlight positions
function M.get_highlights(bufnr)
   bufnr = bufnr or vim.api.nvim_get_current_buf()
   local highlights = {}

   -- Get extmarks from our namespace
   local extmarks = vim.api.nvim_buf_get_extmarks(bufnr, M.ns, 0, -1, { details = true })

   for _, mark in ipairs(extmarks) do
      table.insert(highlights, {
         start_row = mark[2],
         start_col = mark[3],
         end_row = mark[4].end_row or mark[2],
         end_col = mark[4].end_col or mark[3],
      })
   end

   return highlights
end

---Get word at cursor and matching highlights
---@param bufnr? number Buffer number
---@return string? word, table[] highlights
function M.get_word_at_cursor(bufnr)
   bufnr = bufnr or vim.api.nvim_get_current_buf()
   local cursor = vim.api.nvim_win_get_cursor(0)
   local line = vim.api.nvim_buf_get_lines(bufnr, cursor[1] - 1, cursor[1], false)[1]

   if not line then
      return nil, {}
   end

   -- Find word boundaries
   local col = cursor[2] + 1
   local start_col = col
   local end_col = col

   -- Find start of word
   while start_col > 1 and line:sub(start_col - 1, start_col - 1):match("[%w_]") do
      start_col = start_col - 1
   end

   -- Find end of word
   while end_col <= #line and line:sub(end_col, end_col):match("[%w_]") do
      end_col = end_col + 1
   end

   local word = line:sub(start_col, end_col - 1)
   if word == "" then
      return nil, {}
   end

   return word, M.get_highlights(bufnr)
end

---Jump to next/previous highlight
---@param count number Number of highlights to jump (negative for backwards)
---@param wrap? boolean Whether to wrap around
function M.jump(count, wrap)
   local bufnr = vim.api.nvim_get_current_buf()
   local cursor = vim.api.nvim_win_get_cursor(0)
   local highlights = M.get_highlights(bufnr)

   if #highlights == 0 then
      return
   end

   -- Sort highlights by position
   table.sort(highlights, function(a, b)
      if a.start_row == b.start_row then
         return a.start_col < b.start_col
      end
      return a.start_row < b.start_row
   end)

   -- Find current position in highlights
   local current_idx = nil
   for i, hl in ipairs(highlights) do
      if cursor[1] - 1 >= hl.start_row and cursor[1] - 1 <= hl.end_row then
         if cursor[2] >= hl.start_col and cursor[2] <= hl.end_col then
            current_idx = i
            break
         end
      end
   end

   -- Calculate target index
   local target_idx
   if current_idx then
      target_idx = current_idx + count
   else
      -- Find nearest highlight
      target_idx = count > 0 and 1 or #highlights
   end

   -- Handle wrapping
   if wrap then
      target_idx = ((target_idx - 1) % #highlights) + 1
   else
      target_idx = math.max(1, math.min(#highlights, target_idx))
   end

   -- Jump to target
   local target = highlights[target_idx]
   if target then
      vim.api.nvim_win_set_cursor(0, { target.start_row + 1, target.start_col })
   end
end

return M
