---@class Debug
local Debug = {}

---@class DebugLogEntry
---@field level string Log level
---@field timestamp string Formatted timestamp
---@field component string Component name
---@field message string Log message
---@field data? any Additional data
---@field traceback? string Stack trace

---@class CircularBuffer
---@field entries DebugLogEntry[] Log entries
---@field capacity number Maximum entries
---@field head number Current write position
---@field size number Current number of entries

-- Configuration
Debug.config = {
   enabled = true,
   max_entries = 1000,
   file_logging = false,
   file_path = vim.fn.stdpath("cache") .. "/nvim_debug.log",
   levels = {
      ERROR = 1,
      WARN = 2,
      INFO = 3,
      DEBUG = 4,
      TRACE = 5,
   },
   min_level = "INFO",
}

-- Circular buffer for log entries
local log_buffer = {
   entries = {},
   capacity = Debug.config.max_entries,
   head = 1,
   size = 0,
}

---Initialize circular buffer
local function init_buffer()
   for i = 1, log_buffer.capacity do
      log_buffer.entries[i] = nil
   end
end

---Add entry to circular buffer
---@param entry DebugLogEntry
local function add_to_buffer(entry)
   log_buffer.entries[log_buffer.head] = entry
   log_buffer.head = (log_buffer.head % log_buffer.capacity) + 1
   log_buffer.size = math.min(log_buffer.size + 1, log_buffer.capacity)
end

---Get all entries from circular buffer
---@return DebugLogEntry[]
local function get_buffer_entries()
   local entries = {}

   if log_buffer.size == 0 then
      return entries
   end

   local start_idx = log_buffer.size < log_buffer.capacity and 1 or log_buffer.head

   for i = 0, log_buffer.size - 1 do
      local idx = ((start_idx + i - 1) % log_buffer.capacity) + 1
      if log_buffer.entries[idx] then
         table.insert(entries, log_buffer.entries[idx])
      end
   end

   return entries
end

---Get location info from debug stack
---@return string location
function Debug.get_loc()
   local current = debug.getinfo(1, "S")
   local level = 2
   local info = debug.getinfo(level, "S")

   -- Skip internal calls
   while info and (info.source == current.source or info.source == "@" .. vim.env.MYVIMRC or info.what ~= "Lua") do
      level = level + 1
      info = debug.getinfo(level, "S")
   end

   info = info or current
   local source = info.source:sub(2)
   source = vim.uv.fs_realpath(source) or source

   -- Make path relative to config
   local config_path = vim.fn.stdpath("config")
   if vim.startswith(source, config_path) then
      source = source:sub(#config_path + 2)
   end

   return source .. ":" .. info.linedefined
end

---@class DumpOptions
---@field loc? string Location where dump was called from
---@field bt? boolean Include backtrace
---@field timeout? boolean|number Notification timeout

---Internal dump function
---@param value any The value to dump
---@param opts? DumpOptions
function Debug._dump(value, opts)
   opts = opts or {}
   opts.loc = opts.loc or Debug.get_loc()

   -- Handle fast events by scheduling
   if vim.in_fast_event() then
      return vim.schedule(function()
         Debug._dump(value, opts)
      end)
   end

   opts.loc = vim.fn.fnamemodify(opts.loc, ":~:.")
   local msg = vim.inspect(value)

   if opts.bt then
      msg = msg .. "\n" .. debug.traceback("", 2)
   end

   -- Log to debug system
   Debug.log("DEBUG", "dump", opts.loc, { value = value })

   -- Show notification
   vim.notify(msg, vim.log.levels.DEBUG, {
      title = "Debug: " .. opts.loc,
      timeout = opts.timeout,
      on_open = function(win)
         vim.wo[win].conceallevel = 3
         vim.wo[win].concealcursor = ""
         vim.wo[win].spell = false

         local buf = vim.api.nvim_win_get_buf(win)
         if not pcall(vim.treesitter.start, buf, "lua") then
            vim.bo[buf].filetype = "lua"
         end
      end,
   })
end

---Dump one or more values for debugging
---@vararg any
function Debug.dump(...)
   local value = { ... }
   if vim.tbl_isempty(value) then
      value = {}
   else
      value = vim.islist(value) and vim.tbl_count(value) <= 1 and value[1] or value
   end
   Debug._dump(value)
end

---Dump with backtrace
---@vararg any
function Debug.backtrace(...)
   local value = { ... }
   if vim.tbl_isempty(value) then
      value = {}
   else
      value = vim.islist(value) and vim.tbl_count(value) <= 1 and value[1] or value
   end
   Debug._dump(value, { bt = true, timeout = false })
end

---Get upvalue from function
---@param func function
---@param name string
---@return any? value
function Debug.get_upvalue(func, name)
   local index = 1
   while true do
      local upvalue_name, upvalue_value = debug.getupvalue(func, index)
      if not upvalue_name then
         break
      end
      if upvalue_name == name then
         return upvalue_value
      end
      index = index + 1
   end
end

---Log message
---@param level string Log level
---@param component string Component name
---@param message string Message
---@param data? any Additional data
function Debug.log(level, component, message, data)
   if not Debug.config.enabled then
      return
   end

   -- Check minimum level
   local level_num = Debug.config.levels[level] or Debug.config.levels.INFO
   local min_level_num = Debug.config.levels[Debug.config.min_level] or Debug.config.levels.INFO

   if level_num > min_level_num then
      return
   end

   local entry = {
      level = level,
      timestamp = os.date("%Y-%m-%d %H:%M:%S"),
      component = component,
      message = message,
      data = data,
   }

   -- Add to circular buffer
   add_to_buffer(entry)

   -- File logging if enabled
   if Debug.config.file_logging then
      Debug._write_to_file(entry)
   end
end

---Write log entry to file
---@param entry DebugLogEntry
function Debug._write_to_file(entry)
   local log_line = string.format("[%s] %s %s: %s", entry.timestamp, entry.level, entry.component, entry.message)

   if entry.data then
      log_line = log_line .. " " .. vim.inspect(entry.data)
   end

   log_line = log_line .. "\n"

   -- Ensure directory exists
   local dir = vim.fn.fnamemodify(Debug.config.file_path, ":h")
   vim.fn.mkdir(dir, "p")

   -- Append to file
   local file = io.open(Debug.config.file_path, "a")
   if file then
      file:write(log_line)
      file:close()
   end
end

---Enable debug logging
function Debug.enable()
   Debug.config.enabled = true
   Debug.log("INFO", "System", "Debug logging enabled")
end

---Disable debug logging
function Debug.disable()
   Debug.log("INFO", "System", "Debug logging disabled")
   Debug.config.enabled = false
end

---Get debug log entries
---@param filter? {level?: string, component?: string, limit?: number}
---@return DebugLogEntry[]
function Debug.get_log(filter)
   filter = filter or {}
   local entries = get_buffer_entries()

   -- Apply filters
   if filter.level then
      local level_num = Debug.config.levels[filter.level]
      entries = vim.tbl_filter(function(entry)
         return (Debug.config.levels[entry.level] or 0) <= level_num
      end, entries)
   end

   if filter.component then
      entries = vim.tbl_filter(function(entry)
         return entry.component:match(filter.component)
      end, entries)
   end

   -- Apply limit
   if filter.limit and #entries > filter.limit then
      local start = #entries - filter.limit + 1
      entries = vim.list_slice(entries, start)
   end

   return entries
end

---Clear debug log
function Debug.clear_log()
   log_buffer.head = 1
   log_buffer.size = 0
   init_buffer()

   if Debug.config.file_logging then
      local file = io.open(Debug.config.file_path, "w")
      if file then
         file:close()
      end
   end
end

---Configure debug module
---@param opts? table Configuration options
function Debug.setup(opts)
   if opts then
      Debug.config = vim.tbl_deep_extend("force", Debug.config, opts)

      -- Resize buffer if needed
      if opts.max_entries and opts.max_entries ~= log_buffer.capacity then
         log_buffer.capacity = opts.max_entries
         init_buffer()
      end
   end
end

---Show debug log in buffer
function Debug.show_log()
   local entries = Debug.get_log()

   if #entries == 0 then
      vim.notify("Debug log is empty", vim.log.levels.INFO)
      return
   end

   -- Create buffer
   local buf = vim.api.nvim_create_buf(false, true)
   vim.bo[buf].buftype = "nofile"
   vim.bo[buf].bufhidden = "wipe"
   vim.bo[buf].filetype = "debuglog"

   -- Format entries
   local lines = {}
   for _, entry in ipairs(entries) do
      local line = string.format("[%s] %s %s: %s", entry.timestamp, entry.level, entry.component, entry.message)
      table.insert(lines, line)

      if entry.data then
         local data_lines = vim.split(vim.inspect(entry.data), "\n")
         for _, data_line in ipairs(data_lines) do
            table.insert(lines, "  " .. data_line)
         end
      end
   end

   -- Set content
   vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
   vim.bo[buf].modifiable = false

   -- Open in split
   vim.cmd("split")
   vim.api.nvim_win_set_buf(0, buf)
end

-- User commands
vim.api.nvim_create_user_command("DebugLog", function(args)
   if args.args == "clear" then
      Debug.clear_log()
      vim.notify("Debug log cleared", vim.log.levels.INFO)
   else
      Debug.show_log()
   end
end, {
   nargs = "?",
   complete = function()
      return { "clear" }
   end,
})

vim.api.nvim_create_user_command("DebugDump", function(args)
   local code = "return " .. args.args
   local ok, value = pcall(loadstring(code))
   if ok then
      Debug.dump(value)
   else
      vim.notify("Invalid expression: " .. tostring(value), vim.log.levels.ERROR)
   end
end, {
   nargs = "+",
   desc = "Dump the result of a Lua expression",
})

-- Initialize buffer
init_buffer()

return Debug
