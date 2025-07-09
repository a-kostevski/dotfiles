---@class AIHelpers AI helper utilities
local M = {}

---Get visual selection text
---@return string? selected_text The selected text or nil if not in visual mode
function M.get_visual_selection()
   local mode = vim.fn.mode()
   if mode ~= "v" and mode ~= "V" and mode ~= "\22" then
      return nil
   end

   -- Get selection boundaries
   local start_pos = vim.fn.getpos("'<")
   local end_pos = vim.fn.getpos("'>")
   local start_line = start_pos[2]
   local end_line = end_pos[2]
   local start_col = start_pos[3]
   local end_col = end_pos[3]

   -- Get lines
   local lines = vim.api.nvim_buf_get_lines(0, start_line - 1, end_line, false)

   if #lines == 0 then
      return nil
   end

   -- Handle single line selection
   if #lines == 1 then
      return string.sub(lines[1], start_col, end_col)
   end

   -- Handle multi-line selection
   lines[1] = string.sub(lines[1], start_col)
   lines[#lines] = string.sub(lines[#lines], 1, end_col)

   return table.concat(lines, "\n")
end

---Get current buffer content or selection
---@return string content The content
---@return "selection"|"buffer" type The type of content
function M.get_context()
   -- Check for visual selection first
   local selection = M.get_visual_selection()
   if selection then
      return selection, "selection"
   end

   -- Fall back to entire buffer
   local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
   return table.concat(lines, "\n"), "buffer"
end

---@class FileContext
---@field filename string File path
---@field filetype string File type
---@field content string File content
---@field line_count integer Number of lines
---@field modified boolean Whether buffer is modified

---Get file context with metadata
---@param bufnr? integer Buffer number (0 or nil for current)
---@return FileContext context File context information
function M.get_file_context(bufnr)
   bufnr = bufnr or vim.api.nvim_get_current_buf()

   local filename = vim.api.nvim_buf_get_name(bufnr)
   local filetype = vim.bo[bufnr].filetype
   local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

   return {
      filename = filename,
      filetype = filetype,
      content = table.concat(lines, "\n"),
      line_count = #lines,
      modified = vim.bo[bufnr].modified,
   }
end

---@class DiagnosticContext
---@field line integer Line number (1-based)
---@field col integer Column number (1-based)
---@field severity string Severity level
---@field message string Diagnostic message
---@field source? string Diagnostic source

---Get diagnostics context for current buffer
---@param bufnr? integer Buffer number (0 or nil for current)
---@return DiagnosticContext[] diagnostics Array of diagnostic contexts
function M.get_diagnostics_context(bufnr)
   bufnr = bufnr or vim.api.nvim_get_current_buf()

   local diagnostics = vim.diagnostic.get(bufnr)
   local formatted = {}

   for _, diag in ipairs(diagnostics) do
      table.insert(formatted, {
         line = diag.lnum + 1,
         col = diag.col + 1,
         severity = vim.diagnostic.severity[diag.severity],
         message = diag.message,
         source = diag.source,
      })
   end

   return formatted
end

---Get git diff context (staged or unstaged)
---@return string? diff Git diff output or nil if not in git repo
function M.get_git_diff()
   local ok, result = pcall(vim.fn.system, "git diff --cached")
   if ok and vim.v.shell_error == 0 then
      return result
   end

   -- Try unstaged changes
   ok, result = pcall(vim.fn.system, "git diff")
   if ok and vim.v.shell_error == 0 then
      return result
   end

   return nil
end

---Format code block for AI prompt
---@param code string Code content
---@param language? string Programming language (defaults to filetype)
---@return string formatted Markdown formatted code block
function M.format_code_block(code, language)
   language = language or vim.bo.filetype or "text"
   return string.format("```%s\n%s\n```", language, code)
end

---@class BuildContextOptions
---@field include_diagnostics? boolean Include diagnostics in context
---@field include_git? boolean Include git diff in context

---Build context string for AI prompt
---@param opts? BuildContextOptions Options for context building
---@return string context Complete context string
function M.build_context(opts)
   opts = opts or {}
   local parts = {}

   -- Add file context
   local file_ctx = M.get_file_context()
   table.insert(parts, string.format("File: %s", file_ctx.filename))
   table.insert(parts, string.format("Language: %s", file_ctx.filetype))

   -- Add diagnostics if requested
   if opts.include_diagnostics then
      local diagnostics = M.get_diagnostics_context()
      if #diagnostics > 0 then
         table.insert(parts, "\nDiagnostics:")
         for _, diag in ipairs(diagnostics) do
            table.insert(parts, string.format("  Line %d: [%s] %s", diag.line, diag.severity, diag.message))
         end
      end
   end

   -- Add git context if requested
   if opts.include_git then
      local diff = M.get_git_diff()
      if diff then
         table.insert(parts, "\nGit Changes:")
         table.insert(parts, M.format_code_block(diff, "diff"))
      end
   end

   -- Add code content
   table.insert(parts, "\nCode:")
   table.insert(parts, M.format_code_block(file_ctx.content, file_ctx.filetype))

   return table.concat(parts, "\n")
end

---@class CodeBlock
---@field language? string Programming language
---@field content string Code content

---Extract code blocks from AI response
---@param response string AI response text
---@return CodeBlock[] code_blocks Array of extracted code blocks
function M.extract_code_blocks(response)
   local blocks = {}

   -- Pattern to match code blocks with optional language
   local pattern = "```(%w*)%s*\n(.-)\n```"

   for lang, code in response:gmatch(pattern) do
      table.insert(blocks, {
         language = lang ~= "" and lang or nil,
         content = code,
      })
   end

   return blocks
end

---Apply code suggestion to buffer
---@param suggestion string Code suggestion to apply
---@param mode? "replace"|"append"|"prepend" Application mode (default: "replace")
function M.apply_suggestion(suggestion, mode)
   mode = mode or "replace"

   local lines = vim.split(suggestion, "\n", { plain = true })

   if mode == "replace" then
      -- Replace entire buffer
      vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
   elseif mode == "append" then
      -- Append to end of buffer
      local line_count = vim.api.nvim_buf_line_count(0)
      vim.api.nvim_buf_set_lines(0, line_count, line_count, false, lines)
   elseif mode == "prepend" then
      -- Prepend to beginning of buffer
      vim.api.nvim_buf_set_lines(0, 0, 0, false, lines)
   end
end

return M
