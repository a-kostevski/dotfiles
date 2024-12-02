---@class Debug
local Debug = {}

---Get the source location of the caller
---@return string location The file path and line number where the debug call originated
function Debug.get_loc()
   local current = debug.getinfo(1, "S")
   local level = 2
   local info = debug.getinfo(level, "S")
   while info and (info.source == current.source or info.source == "@" .. vim.env.MYVIMRC or info.what ~= "Lua") do
      level = level + 1
      info = debug.getinfo(level, "S")
   end
   info = info or current
   local source = info.source:sub(2)
   source = vim.uv.fs_realpath(source) or source
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

   Utils.notify.info(msg, {
      title = "Debug: " .. opts.loc,
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
      value = nil
   else
      value = vim.islist(value) and vim.tbl_count(value) <= 1 and value[1] or value
   end
   Debug._dump(value)
end

---Dump one or more values with backtrace
---@vararg any
function Debug.backtrace(...)
   local value = { ... }
   if vim.tbl_isempty(value) then
      value = nil
   else
      value = vim.tbl_islist(value) and vim.tbl_count(value) <= 1 and value[1] or value
   end
   Debug._dump(value, { bt = true, timeout = false })
end

---Get an upvalue from a function by name
---@param func function The function to inspect
---@param name string The name of the upvalue to retrieve
---@return any? value The value of the upvalue if found
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

return Debug
