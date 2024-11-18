local M = {}

function M.get_loc()
   local me = debug.getinfo(1, "S")
   local level = 2
   local info = debug.getinfo(level, "S")
   while info and (info.source == me.source or info.source == "@" .. vim.env.MYVIMRC or info.what ~= "Lua") do
      level = level + 1
      info = debug.getinfo(level, "S")
   end
   info = info or me
   local source = info.source:sub(2)
   source = vim.uv.fs_realpath(source) or source
   return source .. ":" .. info.linedefined
end

---@param value any
---@param opts? {loc:string, bt?:boolean}
function M._dump(value, opts)
   opts = opts or {}
   opts.loc = opts.loc or M.get_loc()
   if vim.in_fast_event() then
      return vim.schedule(function()
         M._dump(value, opts)
      end)
   end
   opts.loc = vim.fn.fnamemodify(opts.loc, ":~:.")
   local msg = vim.inspect(value)
   if opts.bt then
      msg = msg .. "\n" .. debug.traceback("", 2)
   end
   vim.notify(msg, vim.log.levels.INFO, {
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

function M.dump(...)
   local value = { ... }
   if vim.tbl_isempty(value) then
      value = nil
   else
      value = (vim.islist or vim.tbl_islist)(value) and vim.tbl_count(value) <= 1 and value[1] or value
   end
   M._dump(value)
end

function M.bt(...)
   local value = { ... }
   if vim.tbl_isempty(value) then
      value = nil
   else
      value = (vim.islist or vim.tbl_islist)(value) and vim.tbl_count(value) <= 1 and value[1] or value
   end
   M._dump(value, { bt = true })
end

function M.get_upvalue(func, name)
   local i = 1
   while true do
      local n, v = debug.getupvalue(func, i)
      if not n then
         break
      end
      if n == name then
         return v
      end
      i = i + 1
   end
end

---@type table<fun(), {id:number, event: string|string[], group?:string|number, loc:string, cb:fun(), count:number, time:number}>
local events = {}

function M.autocmds()
   local au = vim.api.nvim_create_autocmd

   vim.api.nvim_create_autocmd = function(event, opts)
      local id
      local cb = opts.callback
      if cb then
         local info = debug.getinfo(cb)
         local loc = vim.fn.fnamemodify(info.source:sub(2), ":~:.") .. ":" .. info.linedefined
         opts.callback = function(...)
            events[cb] = events[cb]
               or { id = id, event = event, count = 0, time = 0, loc = loc, group = opts.group, pattern = opts.pattern }
            local start = vim.uv.hrtime()
            local ok, err = pcall(cb, ...)
            events[cb].time = events[cb].time + (vim.uv.hrtime() - start) / 1e6
            events[cb].count = events[cb].count + 1
            return not ok and error(err) or err
         end
      end

      vim.api.nvim_create_user_command("DebugAutocmds", function()
         local data = vim.tbl_values(events)
         local all = vim.api.nvim_get_autocmds({})
         for _, v in ipairs(data) do
            v.avg = v.time / v.count
            if type(v.group) == "number" then
               for _, a in ipairs(all) do
                  if a.id == v.id then
                     v.group = a.group_name
                     break
                  end
               end
            end
         end
         table.sort(data, function(a, b)
            return a.time > b.time
         end)
         dd(data)
      end, {})

      id = au(event, opts)
      return id
   end
end

return M
