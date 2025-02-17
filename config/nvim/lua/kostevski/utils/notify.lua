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

   local text
   if type(message) == "table" then
      text = vim.islist(message) and table.concat(message, "\n") or vim.inspect(message)
   else
      text = tostring(message)
   end

   text = sanitize(text)

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

   if prefix then
      table.insert(parts, prefix)
   end

   if title then
      table.insert(parts, sanitize(title))
   end

   local final_title = table.concat(parts, " - ")

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
   for _, item in ipairs(items) do
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
---@field level string|integer Minimum log level
---@field timeout number Default timeout in milliseconds
---@field max_width number|function Max columns for messages
---@field max_height number|function Max lines for messages
---@field stages string|function[] Animation stages
---@field background_colour string Background color
---@field icons table Icons for each level
---@field on_open function Window open callback
---@field on_close function Window close callback
---@field render function|string Renderer
---@field minimum_width integer Min window width
---@field fps integer Animation FPS
---@field top_down boolean Position at top

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
   icons = require("kostevski.utils.ui").icons.diagnostics,
   on_open = function(win)
      return Notify.setup_window(win)
   end,
   render = "minimal",
   fps = 30,
   top_down = true,
}

---@param win number Window handle
function Notify.setup_window(win)
   local win_opts = {
      conceallevel = 3,
      concealcursor = "",
      spell = false,
   }

   for opt, value in pairs(win_opts) do
      vim.wo[win][opt] = value
   end

   local buf = vim.api.nvim_win_get_buf(win)
   vim.bo[buf].filetype = "markdown"
end

---@param msg string|table Message content
---@param level number|string Notification level
---@param opts? table Additional options
---@return table|nil notification_handle
function Notify.notify(msg, level, opts)
   if vim.in_fast_event() then
      return vim.schedule(function()
         Notify.notify(msg, level, opts)
      end)
   end

   local ok, result = pcall(function()
      local format_msg = Format.message(msg)
      if not format_msg then
         return nil
      end

      opts = vim.tbl_deep_extend("force", {}, opts or {})
      opts.title = Format.title(opts.title or "Nvim")

      return vim.notify(format_msg, level, opts)
   end)

   if not ok then
      vim.schedule(function()
         vim.notify("Notification error: " .. tostring(result), vim.log.levels.ERROR)
      end)
      return nil
   end

   return result
end

local function create_level_notifier(level)
   return function(message, opts)
      return Notify.notify(message, level, opts or {})
   end
end

Notify.error = create_level_notifier("error")
Notify.warn = create_level_notifier("warn")
Notify.info = create_level_notifier("info")

local client_notifs = {}
local spinner_frames = require("kostevski.utils.ui").icons.misc.spinner_frames

local function get_notif_data(client_id, token)
   client_notifs[client_id] = client_notifs[client_id] or {}
   client_notifs[client_id][token] = client_notifs[client_id][token] or {}
   return client_notifs[client_id][token]
end

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

---@param result {token: string, value: {kind: string, title?: string, message?: string, percentage?: number}}
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
         hide_from_history = true,
      })
   elseif val.kind == "end" and notif_data then
      local message = val.message and Format.message(val.message) or "Complete"
      notif_data.notification = Notify.info(message, {
         replace = notif_data.notification,
         timeout = 3000,
         hide_from_history = false,
      })
      notif_data.spinner = nil
   end
end
local severity = { "error", "warn", "info", "hint" }
local last_notification = 0
local RATE_LIMIT_MS = 100

---@param client_id number|nil The ID of the LSP client
---@param method table LSP method containing message
---@param params table Parameters containing message type
---@param _ any Unused ctx parameter
vim.lsp.handlers["window/showMessage"] = function(client_id, method, params, _)
   if not method or not params then
      return
   end

   local current_time = vim.loop.now()
   if current_time - last_notification < RATE_LIMIT_MS then
      return
   end
   last_notification = current_time

   local client = client_id and vim.lsp.get_client_by_id(client_id)
   local source = client and client.name or "LSP"
   -- Notify.notify(method.message, severity[params.type], { title = source })
   vim.notify(method.message, severity[params.type], { title = source })
end
return Notify
