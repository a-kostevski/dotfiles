---@class LspHandlers
local M = {}

---Configure LSP handlers with better UI
function M.setup()
   -- Hover handler with border and modern configuration
   vim.lsp.handlers["textDocument/hover"] = vim.lsp.with(vim.lsp.handlers.hover, {
      border = "rounded",
      max_width = 80,
      max_height = 20,
      focusable = false,
      close_events = { "BufLeave", "CursorMoved", "InsertEnter", "FocusLost" },
   })

   -- Signature help with border and modern configuration
   vim.lsp.handlers["textDocument/signatureHelp"] = vim.lsp.with(vim.lsp.handlers.signature_help, {
      border = "rounded",
      focusable = false,
      relative = "cursor",
      max_width = 80,
      close_events = { "BufLeave", "CursorMoved", "InsertEnter", "FocusLost" },
   })

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
      -- Only show errors in log messages (not warnings)
      if result.type == vim.lsp.protocol.MessageType.Error then
         handleMessage(_, result, ctx)
      end
   end

   -- Rename handler with better UI and modern workspace edit handling
   local orig_rename = vim.lsp.handlers["textDocument/rename"]
   vim.lsp.handlers["textDocument/rename"] = function(err, result, ctx, config)
      if err then
         vim.notify("Rename failed: " .. err.message, vim.log.levels.ERROR)
         return
      end

      -- Call original handler
      orig_rename(err, result, ctx, config)

      -- Show rename summary for both workspace edits and document changes
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

   -- Code action handler with modern filtering and command support
   local orig_code_action = vim.lsp.handlers["textDocument/codeAction"]
   if orig_code_action then
      vim.lsp.handlers["textDocument/codeAction"] = function(err, result, ctx, config)
         if err then
            vim.notify("Code action failed: " .. err.message, vim.log.levels.ERROR)
            return
         end

         -- Filter out empty results and validate code actions
         if result and type(result) == "table" then
            result = vim.tbl_filter(function(action)
               return action and (action.title or action.command) and (action.edit or action.command or action.data)
            end, result)
         end

         orig_code_action(err, result, ctx, config)
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

---Configure diagnostic display with modern configuration
function M.setup_diagnostics()
   local signs = {
      Error = " ",
      Warn = " ",
      Hint = " ",
      Info = " ",
   }

   for type, icon in pairs(signs) do
      local hl = "DiagnosticSign" .. type
      vim.fn.sign_define(hl, { text = icon, texthl = hl, numhl = hl })
   end

   vim.diagnostic.config({
      virtual_text = {
         spacing = 4,
         source = "if_many",
         prefix = "●",
         -- Only show errors in virtual text
         severity = {
            min = vim.diagnostic.severity.HINT,
         },
         -- Modern suffix support for LSP error codes
         suffix = " ",
      },
      float = {
         focusable = false,
         style = "minimal",
         border = "rounded",
         source = "if_many",
         header = "",
         prefix = "",
         -- Modern suffix support for LSP error codes
         suffix = function(diagnostic)
            local code = diagnostic.code
            if code then
               return string.format(" [%s]", code)
            end
            return ""
         end,
         format = function(diagnostic)
            -- Add source to diagnostic message
            if diagnostic.source then
               return string.format("[%s] %s", diagnostic.source, diagnostic.message)
            end
            return diagnostic.message
         end,
      },
      signs = {
         severity = { min = vim.diagnostic.severity.HINT },
      },
      underline = true,
      update_in_insert = false,
      severity_sort = true,
   })
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
      "$/progress",
   }

   local lines = { "# LSP Handlers\n" }

   for _, handler in ipairs(handlers) do
      local has_handler = vim.lsp.handlers[handler] ~= nil
      local status = has_handler and "" or ""
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
      -- Show all messages
      vim.lsp.handlers["window/logMessage"] = vim.lsp.handlers["window/showMessage"]

      -- Enable progress notifications
      vim.lsp.handlers["$/progress"] = function(_, result, ctx)
         local Utils = require("kostevski.utils")
         if Utils and Utils.notify and Utils.notify.progress then
            Utils.notify.progress(result, ctx)
         end
      end

      vim.notify("Verbose LSP notifications enabled", vim.log.levels.INFO)
   else
      -- Restore quiet handlers
      M.setup()

      -- Ensure progress is still tracked silently
      local Utils = require("kostevski.utils")
      if Utils and Utils.lsp and Utils.lsp.progress then
         Utils.lsp.progress.setup()
      end

      vim.notify("Verbose LSP notifications disabled", vim.log.levels.INFO)
   end
end

-- Create user command
vim.api.nvim_create_user_command("LspVerbose", function()
   M.toggle_verbose()
end, { desc = "Toggle verbose LSP notifications" })

return M
