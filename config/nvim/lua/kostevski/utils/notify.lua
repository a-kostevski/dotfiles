local Format = {}

-- Constants
local MAX_TITLE_LENGTH = 50
local MAX_MESSAGE_SIZE = 1024
local ELLIPSIS = "..."

---@param text string The text to truncate
---@param max_length number Maximum length
---@return string truncated_text
local function truncate(text, max_length)
   if not text or #text <= max_length then
      return text
   end
   return string.sub(text, 1, max_length - #ELLIPSIS) .. ELLIPSIS
end

---@param text string Text to sanitize
---@return string sanitized_text
local function sanitize(text)
   if type(text) ~= "string" then
      return tostring(text)
   end
   -- Remove control characters
   -- text = text:gsub("[\0-\31]", "")
   -- Convert tabs to spaces
   text = text:gsub("\t", "  ")
   return text
end

---@param message any The message to format
---@param progress? number Optional progress percentage
---@return string|nil formatted_message
function Format.message(message, progress)
   if not message then
      return nil
   end

   -- Convert to string and sanitize
   local text = sanitize(message)
   if #text == 0 then
      return nil
   end

   -- Add progress if provided
   if progress then
      text = string.format("[%d%%]\t %s", progress, text)
   end

   if #text > MAX_MESSAGE_SIZE then
      text = text:sub(1, MAX_MESSAGE_SIZE) .. ELLIPSIS
   end

   -- Apply markdown formatting for code blocks
   text = text:gsub("```(.-)```", function(code)
      return string.format("\n```\n%s\n```", code)
   end)

   return text
end

---@param title? string The title to format
---@param level? number Message level (vim.log.levels)
---@param prefix? string Optional prefix (e.g., LSP client name)
---@return string formatted_title
function Format.title(title, level, prefix)
   local parts = {}

   -- Add prefix if provided
   if prefix then
      table.insert(parts, prefix)
   end

   -- Add title if provided
   if title then
      table.insert(parts, sanitize(title))
   end

   -- Join parts with separator
   local final_title = table.concat(parts, " - ")

   -- Add level indicator if provided
   if level then
      local level_name = vim.log.levels[level] or "INFO"
      final_title = string.format("[%s] %s", level_name:upper(), final_title)
   end

   return truncate(final_title, MAX_TITLE_LENGTH)
end

---@param text string Text to format as code
---@return string formatted_code
function Format.code(text)
   return string.format("```\n%s\n```", sanitize(text))
end

---@param items string[] List of items to format
---@return string formatted_list
function Format.list(items)
   local formatted = {}
   for i, item in ipairs(items) do
      table.insert(formatted, string.format("• %s", sanitize(item)))
   end
   return table.concat(formatted, "\n")
end

---@param text string Text to highlight
---@param hl_group? string Optional highlight group
---@return string highlighted_text
function Format.highlight(text, hl_group)
   if not hl_group then
      return sanitize(text)
   end
   return string.format("**%s**", sanitize(text))
end

local Notify = {}

---@class NotifyOptions
---@field title string
---@field icon string
---@field timeout number|boolean Time to show notification in milliseconds, set to false to disable timeou
---@field on_open function Callback for when window opens, receives window as argumen
---@field on_close function Callback for when window closes, receives window as argumen
---@field keep function Function to keep the notification window open after timeout, should return boolea
---@field render function|string Function to render a notification buffe
---@field replace integer|notify.Record Notification record or the record `id` field. Replace an existing notification if still open. All arguments not given are inherited from the replaced notification including message and leve
---@field hide_from_history boolean Hide this notification from the histo
---@field animate boolean If false, the window will jump to the timed stage. Intended for use in blocking events (e.g. vim.fn.inpu

Notify.default_opts = {
   title = "Nvim",
   icon = "",
   timeout = 5000,
   max_width = 50,
   on_open = nil,
   on_close = nil,
   keep = false,
   render = "default",
   replace = nil,
   hide_from_history = false,
   animate = false,
}

---@class NotifyConfig
---@field level string|integer Minimum log level to display. See vim.log.levels.
---@field timeout `(number)` Default timeout for notification
---@field max_width `(number|function)` Max number of columns for messages
---@field max_height `(number|function)` Max number of lines for a message
---@field stages `(string|function[])` Animation stages
---@field background_colour `(string)` For stages that change opacity this is treated as the highlight behind the window. Set this to either a highlight group, an RGB hex value e.g. "#000000" or a function returning an RGB code for dynamic values
---@field icons `(table)` Icons for each level (upper case names)
---@field time_formats `(table)` Time formats for different kind of notifications
---@field on_open `(function)` Function called when a new window is opened, use for changing win settings/config
---@field on_close `(function)` Function called when a window is closed
---@field render `(function|string)` Function to render a notification buffer or a built-in renderer name
---@field minimum_width `(integer)` Minimum width for notification windows
---@field fps `(integer)` Frames per second for animation stages, higher value means smoother animations but more CPU usage
---@field top_down `(boolean)` whether or not to position the notifications at the top or not

Notify.default_config = {
   level = vim.log.levels.INFO,
   timeout = 5000,

   max_height = function()
      return math.floor(vim.o.lines * 0.75)
   end,
   max_width = function()
      return math.floor(vim.o.columns * 0.75)
   end,
   stages = "static",
   -- background_color = nil,
   icons = require("kostevski.utils.ui").icons.diagnostics,
   on_open = function(win)
      return Notify.setup_window(win)
   end,
   -- on_close = function() end,
   render = "minimal",
   -- minimum_width = 30,
   fps = 30,
   top_down = true,
}

function Notify.setup_window(win)
   -- Window options
   local win_opts = {
      conceallevel = 3,
      concealcursor = "",
      spell = false,
   }
   for opt, value in pairs(win_opts) do
      vim.wo[win][opt] = value
   end

   -- Buffer setup with fallback
   local buf = vim.api.nvim_win_get_buf(win)
   vim.bo[buf].filetype = "markdown"
   vim.bo[buf].syntax = "markdown"
end

function Notify.notify(msg, level, opts)
   Utils.debug.log("notify.notify", "Notification requested", {
      msg = msg,
      level = level,
      opts = opts,
   })

   -- Handle fast events
   if vim.in_fast_event() then
      return vim.schedule(function()
         Notify.notify(msg, level, opts)
      end)
   end

   local success, result = pcall(function()
      local format_msg = Format.message(msg)
      if not format_msg then
         Utils.debug.log("notify.notify", "Message validation failed")
         return nil
      end

      opts = vim.tbl_deep_extend("force", Notify.default_opts, opts or {})

      -- Set notification properties
      -- opts.on_open = opts.on_open or setup_window
      opts.title = Format.title(opts.title or "Nvim")

      Utils.debug.log("notify.notify", "Opts are: ", opts)
      return vim.notify(format_msg, level, opts)
   end)

   if not success then
      Utils.debug.log("notify.notify", "Notification error", {
         error = result,
      })
      vim.schedule(function()
         vim.notify("Notification error: " .. tostring(result), vim.log.levels.ERROR)
      end)
      return nil
   end

   return result
end

local function create_level_notifier(level)
   return function(message, opts)
      opts = opts or {}
      return Notify.notify(message, level, opts)
   end
end

Notify.error = create_level_notifier("error")
Notify.warn = create_level_notifier("warn")
Notify.info = create_level_notifier("info")

local client_notifs = {}

local function get_notif_data(client_id, token)
   if not client_notifs[client_id] then
      client_notifs[client_id] = {}
   end

   if not client_notifs[client_id][token] then
      client_notifs[client_id][token] = {}
   end

   return client_notifs[client_id][token]
end

local spinner_frames = require("kostevski.utils.ui").icons.misc.spinner_frames

local function update_spinner(client_id, token)
   local notif_data = get_notif_data(client_id, token)

   if notif_data.spinner then
      local new_spinner = (notif_data.spinner + 1) % #spinner_frames
      notif_data.spinner = new_spinner

      notif_data.notification = vim.notify("", nil, {
         hide_from_history = true,
         icon = spinner_frames[new_spinner],
         replace = notif_data.notification,
      })

      vim.defer_fn(function()
         update_spinner(client_id, token)
      end, 3000)
   end
end

--- @see #https://microsoft.github.io/language-server-protocol/specifications/specification-current/#progress
--- @param result lsp.ProgressParams
--- @param ctx lsp.HandlerContext
--- @diagnostic disable-next-line:no-unknown
vim.lsp.handlers["$/progress"] = function(_, result, ctx)
   local client_id = ctx.client_id

   local client = vim.lsp.get_client_by_id(client_id)
   if not client then
      Notify.error("Invalid LSP client ID: " .. tostring(client_id))
      return
   end

   local val = result.value

   if not val.kind then
      return
   end

   local notif_data = get_notif_data(client_id, result.token)

   if val.kind == "begin" then
      local message = Format.message(val.message, val.percentage)

      notif_data.notification = Notify.info(message, {
         title = Format.title(val.title, vim.log.levels.INFO, client.name),
         icon = spinner_frames[1],
         timeout = false,
         hide_from_history = false,
      })
      notif_data.spinner = 1
      update_spinner(client_id, result.token)
   elseif val.kind == "report" and notif_data then
      local message = Format.message(val.message, val.percentage)
      notif_data.notification = Notify.info(message, {
         replace = notif_data.notification,
         hide_from_history = false,
      })
   elseif val.kind == "end" and notif_data then
      local message = val.message and Format.message(val.message) or "Complete"
      notif_data.notification = Notify.info(message, {
         replace = notif_data.notification,
         timeout = 3000,
         hide_from_history = true,
      })
      notif_data.spinner = nil
   end
end
local severity = { "error", "warn", "info", "hint" }

vim.lsp.handlers["window/showMessage"] = function(_, method, params, _)
   vim.notify(method.message, severity[params.type])
end
return Notify
