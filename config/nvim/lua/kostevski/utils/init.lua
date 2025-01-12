local Utils = {}
_G.Utils = Utils

function Utils.is_list(t)
   local i = 0
   for _ in pairs(t) do
      i = i + 1
      if t[i] == nil then
         return false
      end
   end
   return true
end
local function can_merge(v)
   return type(v) == "table" and (vim.tbl_isempty(v) or not Utils.is_list(v))
end
function Utils.merge(...)
   local ret = select(1, ...)
   if ret == vim.NIL then
      ret = nil
   end
   for i = 2, select("#", ...) do
      local value = select(i, ...)
      if can_merge(ret) and can_merge(value) then
         for k, v in pairs(value) do
            ret[k] = Utils.merge(ret[k], v)
         end
      elseif value == vim.NIL then
         ret = nil
      elseif value ~= nil then
         ret = value
      end
   end
   return ret
end
---@generic T
---@param list T[]
---@return T[]
function Utils.dedup(list)
   local ret = {}
   local seen = {}
   for _, v in ipairs(list) do
      if not seen[v] then
         table.insert(ret, v)
         seen[v] = true
      end
   end
   return ret
end
function Utils.norm(path)
   -- Replace ~ with the home directory
   if path:sub(1, 1) == "~" then
      local home = vim.loop.os_homedir()
      path = home .. path:sub(2)
   end

   -- Normalize path separators and remove duplicate slashes
   path = path:gsub("\\", "/"):gsub("/+", "/")

   -- Remove trailing slash if it exists
   if path:sub(-1) == "/" and #path > 1 then
      path = path:sub(1, -2)
   end

   return path
end

-- From https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/util/init.lua
Utils.CREATE_UNDO = vim.api.nvim_replace_termcodes("<c-G>u", true, true, true)
function Utils.create_undo()
   if vim.api.nvim_get_mode().mode == "i" then
      vim.api.nvim_feedkeys(Utils.CREATE_UNDO, "n", false)
   end
end

function Utils.P(value)
   print(vim.inspect(value))
   return value
end

function Utils.RELOAD(...)
   return require("plenary.reload").reload_module(...)
end

function Utils.R(name)
   Utils.RELOAD(name)
   return require(name)
end

function Utils.debounce(ms, fn)
   local timer = vim.uv.new_timer()
   return function(...)
      local argv = { ... }
      timer:start(ms, 0, function()
         timer:stop()
         vim.schedule_wrap(fn)(unpack(argv))
      end)
   end
end

---@generic R
---@param fn fun():R?
---@param opts? string|{msg:string, on_error:fun(msg)}
---@return R
function Utils.try(fn, opts)
   -- Normalize opts
   local options = type(opts) == "string" and { msg = opts } or opts or {}

   -- Execute function in protected mode
   local ok, result = pcall(fn)

   if ok then
      return result
   end

   -- Handle error case
   local err_msg = options.msg or tostring(result)

   if options.on_error then
      options.on_error(err_msg)
   else
      vim.notify(err_msg, vim.log.levels.ERROR)
   end
   return nil
end

function Utils.setup()
   Utils.debug = require("kostevski.utils.debug")
   Utils.notify = require("kostevski.utils.notify")
   Utils.lsp = require("kostevski.utils.lsp")
   Utils.format = require("kostevski.utils.format")
   Utils.cmp = require("kostevski.utils.cmp")
   Utils.ui = require("kostevski.utils.ui")
   Utils.plugin = require("kostevski.utils.plugin")
   Utils.toggle = require("kostevski.utils.toggle")
   Utils.root = require("kostevski.utils.root")
   Utils.format.setup()
   Utils.root.setup()
end

return Utils
