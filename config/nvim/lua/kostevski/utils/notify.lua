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

return Notify
