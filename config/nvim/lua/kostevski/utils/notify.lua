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
---@field client_name string LSP client name
---@field title? string Progress title

---@class UtilsNotify Notification utilities
---@field config NotifyConfig Module configuration
local Notify = {}

-- Default configuration
---@type NotifyConfig
Notify.config = {
  timeout = 2500,
  max_width = 80,
  max_height = 20,
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

  -- Suppress when paused (still allow hide_from_history messages like pause/resume feedback)
  opts = opts or {}
  if vim.g.notifications_paused and not opts.hide_from_history then
    return nil
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

      local new_handle = vim.notify(
        display_msg,
        level,
        vim.tbl_deep_extend("force", opts, {
          replace = existing.handle,
        })
      )
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
---
---Only shows a notification on completion. Live progress is handled by the
---statusline via lsp.progress.statusline().
---@param result LspProgressResult Progress result
---@param ctx LspProgressContext Context with client_id
function Notify.progress(result, ctx)
  local client_id = ctx.client_id
  local value = result.value
  if not value or not value.kind then
    return
  end

  local key = string.format("%s:%s", client_id, result.token)

  if value.kind == "begin" then
    local client = vim.lsp.get_client_by_id(client_id)
    progress_notifications[key] = {
      client_name = client and client.name or "LSP",
      title = value.title,
    }
  elseif value.kind == "end" then
    local data = progress_notifications[key]
    progress_notifications[key] = nil
    if data then
      Notify.info(value.message or "Complete", {
        title = data.client_name,
        timeout = 2000,
      })
    end
  end
end

---Setup LSP handlers for notifications and progress
---@deprecated Use lsp.handlers and lsp.progress modules instead
function Notify.setup_lsp_handlers()
  -- No-op: LSP handlers are now managed by lsp.handlers and lsp.progress modules
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
