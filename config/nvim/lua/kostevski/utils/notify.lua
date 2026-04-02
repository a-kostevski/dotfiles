---@alias NotifyLevel integer|string Log level (number or string)
---@alias NotifyIcon string Icon character
---@alias NotifySpinnerFrame string Spinner animation frame

---@class NotifyConfig
---@field timeout integer Default timeout in milliseconds
---@field max_width integer Maximum notification width
---@field max_height integer Maximum notification height
---@field icons table<string, NotifyIcon> Icons for log levels
---@field spinner_frames NotifySpinnerFrame[] Spinner animation frames

---@class NotifyOptions
---@field title? string Notification title
---@field timeout? integer|false Timeout in ms (false = no timeout)
---@field icon? string Icon to display
---@field replace? any Previous notification to replace
---@field on_open? fun(win: integer) Callback when window opens
---@field hide_from_history? boolean Hide from notification history

---@class NotifyProgressData
---@field notification any Notification handle
---@field spinner_idx integer Current spinner frame index
---@field client_name string LSP client name

---@class UtilsNotify Notification utilities
---@field config NotifyConfig Module configuration
local Notify = {}

-- Default configuration
---@type NotifyConfig
Notify.config = {
   timeout = 2500,
   max_width = 50,
   max_height = 10,
   icons = {
      ERROR = "",
      WARN = "",
      INFO = "",
      DEBUG = "",
      TRACE = "",
   },
   spinner_frames = { "⣾", "⣽", "⣻", "⢿", "⡿", "⣟", "⣯", "⣷" },
}

-- Progress tracking for LSP
---@type table<string, NotifyProgressData>
local progress_notifications = {}

-- Duplicate notification tracking
---@class ActiveNotification
---@field handle any Notification handle
---@field count integer Duplicate count
---@field original_msg string Original message text
---@field level integer Log level
---@field opts table Notification options

---@type table<string, ActiveNotification>
local active_notifications = {}

---Setup notification module with custom configuration
---@param opts? NotifyConfig Configuration options
function Notify.setup(opts)
   if opts then
      Notify.config = vim.tbl_deep_extend("force", Notify.config, opts)
   end

   -- Setup window options for notifications
   local orig_notify = vim.notify
   -- Create wrapper with more specific name
   local function enhanced_notify(msg, level, notify_opts)
      notify_opts = notify_opts or {}

      if not notify_opts.on_open then
         notify_opts.on_open = function(win)
            vim.wo[win].conceallevel = 3
            vim.wo[win].concealcursor = ""
            vim.wo[win].spell = false

            local buf = vim.api.nvim_win_get_buf(win)
            vim.bo[buf].filetype = "markdown"
         end
      end

      return orig_notify(msg, level, notify_opts)
   end
   vim.notify = enhanced_notify
end

---Generate a dedup key from message and level
---@param msg string
---@param level integer
---@return string
local function dedup_key(msg, level)
   return string.format("%d:%s", level, msg)
end

---Send a notification with formatting and options
---Duplicate messages within the timeout window are collapsed with a counter badge.
---@param msg string|table|any Message content (will be formatted)
---@param level? NotifyLevel Log level (number or string)
---@param opts? NotifyOptions Additional options
---@return any? notification_handle Notification handle or nil if failed
function Notify.notify(msg, level, opts)
   -- Defer if in fast event
   if vim.in_fast_event() then
      return vim.schedule(function()
         return Notify.notify(msg, level, opts)
      end)
   end

   -- Format message
   local Utils = require("kostevski.utils")
   local formatted_msg = Utils.strings.message(msg)
   if not formatted_msg then
      return nil
   end

   -- Normalize level
   if type(level) == "string" then
      level = vim.log.levels[level:upper()] or vim.log.levels.INFO
   end
   level = level or vim.log.levels.INFO

   -- Merge options
   opts = vim.tbl_deep_extend("force", {
      timeout = Notify.config.timeout,
   }, opts or {})

   -- Format title if provided
   if opts.title then
      opts.title = Utils.strings.title(opts.title, level)
   end

   -- Check for duplicate: skip dedup if this is a replacement notification (e.g. progress)
   if not opts.replace then
      local key = dedup_key(formatted_msg, level)
      local existing = active_notifications[key]

      if existing and existing.handle then
         -- Increment counter and update existing notification
         existing.count = existing.count + 1
         local display_msg = string.format("%s (x%d)", existing.original_msg, existing.count)

         local new_handle = vim.notify(display_msg, level, vim.tbl_deep_extend("force", opts, {
            replace = existing.handle,
         }))
         existing.handle = new_handle
         return new_handle
      end

      -- New notification: track it
      local handle = vim.notify(formatted_msg, level, opts)
      active_notifications[key] = {
         handle = handle,
         count = 1,
         original_msg = formatted_msg,
         level = level,
         opts = opts,
      }

      -- Clean up tracking after timeout
      local timeout = opts.timeout or Notify.config.timeout
      if timeout and timeout ~= false then
         vim.defer_fn(function()
            active_notifications[key] = nil
         end, timeout + 500)
      end

      return handle
   end

   -- Send notification (for replace/progress notifications, no dedup)
   return vim.notify(formatted_msg, level, opts)
end

-- Convenience methods
---@param msg string|table|any Message content
---@param opts? NotifyOptions Additional options
---@return any? notification_handle
function Notify.error(msg, opts)
   return Notify.notify(msg, vim.log.levels.ERROR, opts)
end

---@param msg string|table|any Message content
---@param opts? NotifyOptions Additional options
---@return any? notification_handle
function Notify.warn(msg, opts)
   return Notify.notify(msg, vim.log.levels.WARN, opts)
end

---@param msg string|table|any Message content
---@param opts? NotifyOptions Additional options
---@return any? notification_handle
function Notify.info(msg, opts)
   return Notify.notify(msg, vim.log.levels.INFO, opts)
end

---@param msg string|table|any Message content
---@param opts? NotifyOptions Additional options
---@return any? notification_handle
function Notify.debug(msg, opts)
   return Notify.notify(msg, vim.log.levels.DEBUG, opts)
end

---@param msg string|table|any Message content
---@param opts? NotifyOptions Additional options
---@return any? notification_handle
function Notify.trace(msg, opts)
   return Notify.notify(msg, vim.log.levels.TRACE, opts)
end

---@class LspProgressValue
---@field kind "begin"|"report"|"end" Progress kind
---@field title? string Progress title
---@field message? string Progress message
---@field percentage? number Progress percentage

---@class LspProgressResult
---@field token string|integer Progress token
---@field value LspProgressValue Progress value

---@class LspProgressContext
---@field client_id integer LSP client ID

---Handle LSP progress notifications
---@param result LspProgressResult Progress result
---@param ctx LspProgressContext Context with client_id
function Notify.progress(result, ctx)
   local client_id = ctx.client_id
   local client = vim.lsp.get_client_by_id(client_id)
   if not client then
      return
   end

   local value = result.value
   if not value or not value.kind then
      return
   end

   local key = string.format("%s:%s", client_id, result.token)

   if value.kind == "begin" then
      local message = value.message or "Loading..."
      if value.percentage then
         message = string.format("%s (%d%%)", message, value.percentage)
      end

      progress_notifications[key] = {
         notification = Notify.info(message, {
            title = string.format("%s - %s", client.name, value.title or "Progress"),
            icon = Notify.config.spinner_frames[1],
            timeout = false,
            replace = progress_notifications[key] and progress_notifications[key].notification,
         }),
         spinner_idx = 1,
         client_name = client.name,
      }

      -- Start spinner animation
      Notify._animate_spinner(key)
   elseif value.kind == "report" and progress_notifications[key] then
      local data = progress_notifications[key]
      local message = value.message or "Processing..."
      if value.percentage then
         message = string.format("%s (%d%%)", message, value.percentage)
      end

      data.notification = Notify.info(message, {
         replace = data.notification,
         timeout = false,
      })
   elseif value.kind == "end" and progress_notifications[key] then
      local data = progress_notifications[key]
      local message = value.message or "Complete"

      Notify.info(message, {
         title = data.client_name,
         replace = data.notification,
         timeout = 3000,
      })

      progress_notifications[key] = nil
   end
end

---Animate spinner for progress notifications
---@private
---@param key string Progress key
function Notify._animate_spinner(key)
   local data = progress_notifications[key]
   if not data then
      return
   end

   vim.defer_fn(function()
      if progress_notifications[key] then
         data.spinner_idx = (data.spinner_idx % #Notify.config.spinner_frames) + 1

         vim.notify(nil, nil, {
            replace = data.notification,
            icon = Notify.config.spinner_frames[data.spinner_idx],
            hide_from_history = true,
         })

         Notify._animate_spinner(key)
      end
   end, 100)
end

---Setup LSP handlers for notifications and progress
function Notify.setup_lsp_handlers()
   -- Progress handler - disabled by default (too noisy)
   -- To enable: vim.lsp.handlers["$/progress"] = function(_, result, ctx)
   --    Notify.progress(result, ctx)
   -- end

   -- Show message handler - only errors and warnings
   vim.lsp.handlers["window/showMessage"] = function(_, result, ctx)
      -- Skip info and log messages
      if result.type > vim.lsp.protocol.MessageType.Warning then
         return
      end

      local client = vim.lsp.get_client_by_id(ctx.client_id)
      local client_name = client and client.name or "LSP"

      ---@type integer[]
      local level_map = {
         vim.lsp.protocol.MessageType.Error,
         vim.lsp.protocol.MessageType.Warning,
         vim.lsp.protocol.MessageType.Info,
         vim.lsp.protocol.MessageType.Log,
      }

      Notify.notify(result.message, level_map[result.type], {
         title = client_name,
      })
   end
end

---@class NotifyFormatOptions
---@field progress? number Progress percentage

---Format a message for display using string utilities
---@param msg any Message to format
---@param opts? NotifyFormatOptions Formatting options
---@return string? formatted Formatted message or nil
function Notify.format_message(msg, opts)
   local Utils = require("kostevski.utils")
   return Utils.strings.message(msg, opts and opts.progress)
end

---Format a title for display using string utilities
---@param title string Title to format
---@param level? integer Log level (vim.log.levels)
---@param prefix? string Optional prefix
---@return string formatted Formatted title
function Notify.format_title(title, level, prefix)
   local Utils = require("kostevski.utils")
   return Utils.strings.title(title, level, prefix)
end

return Notify
