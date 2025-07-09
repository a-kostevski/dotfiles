---@class Utils
---@field debug Debug
---@field notify NotifyUtils
---@field lsp LspUtils
---@field format Format
---@field ui UiUtils
---@field plugin PluginUtils
---@field toggle ToggleUtils
---@field root Root
---@field cache UtilsCache
---@field ai UtilsAi
---@field keys Keys
---@field strings StringUtils
---@field errors UtilsErrors
local Utils = {
   _loaded = {},
   _modules = {
      debug = "kostevski.utils.debug",
      notify = "kostevski.utils.notify",
      lsp = "kostevski.utils.lsp",
      format = "kostevski.utils.format",
      ui = "kostevski.utils.ui",
      plugin = "kostevski.utils.plugin",
      toggle = "kostevski.utils.toggle",
      root = "kostevski.utils.root",
      cache = "kostevski.utils.cache",
      ai = "kostevski.utils.ai",
      keys = "kostevski.utils.keys",
      strings = "kostevski.utils.strings",
      errors = "kostevski.utils.errors",
   },
} -- Metatable for lazy loading modules
setmetatable(Utils, {
   __index = function(self, key)
      -- Check if it's a registered module
      local module_path = self._modules[key]
      if module_path and not self._loaded[key] then
         -- Lazy load the module
         local ok, module = pcall(require, module_path)
         if ok then
            self[key] = module
            self._loaded[key] = true
            return module
         else
            vim.notify(string.format("Failed to load utils.%s: %s", key, module), vim.log.levels.ERROR)
            return nil
         end
      end
      return rawget(self, key)
   end,
})

---Check if a table is a list
---@param t table
---@return boolean
function Utils.is_list(t)
   if type(t) ~= "table" then
      return false
   end
   local i = 0
   for _ in pairs(t) do
      i = i + 1
      if t[i] == nil then
         return false
      end
   end
   return true
end

---Deep merge tables
---@vararg table
---@return table
function Utils.merge(...)
   local function can_merge(v)
      return type(v) == "table" and (vim.tbl_isempty(v) or not Utils.is_list(v))
   end

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

---Remove duplicates from a list
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

---Normalize a file path
---@param path string
---@return string
function Utils.norm(path)
   if not path or path == "" then
      return ""
   end

   -- Replace ~ with the home directory
   if path:sub(1, 1) == "~" then
      local home = vim.loop.os_homedir()
      if home then
         path = home .. path:sub(2)
      end
   end

   -- Normalize path separators and remove duplicate slashes
   path = path:gsub("\\", "/"):gsub("/+", "/")

   -- Remove trailing slash if it exists (except for root)
   if #path > 1 and path:sub(-1) == "/" then
      path = path:sub(1, -2)
   end

   return path
end

-- Terminal codes for creating undo points
Utils.CREATE_UNDO = vim.api.nvim_replace_termcodes("<c-G>u", true, true, true)

---Create an undo point in insert mode
function Utils.create_undo()
   if vim.api.nvim_get_mode().mode == "i" then
      vim.api.nvim_feedkeys(Utils.CREATE_UNDO, "n", false)
   end
end

---Pretty print a value
---@param value any
---@return any
function Utils.P(value)
   print(vim.inspect(value))
   return value
end

---Reload a module
---@param name string Module name
---@return any
function Utils.RELOAD(name)
   local has_plenary, plenary = pcall(require, "plenary.reload")
   if has_plenary then
      return plenary.reload_module(name)
   else
      -- Fallback implementation
      package.loaded[name] = nil
      return require(name)
   end
end

---Reload and require a module
---@param name string Module name
---@return any
function Utils.R(name)
   Utils.RELOAD(name)
   return require(name)
end

---Create a debounced function
---@param ms number Milliseconds to wait
---@param fn function Function to debounce
---@return function
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

---Try to execute a function with error handling
---@generic R
---@param fn fun():R?
---@param opts? string|{msg:string, on_error:fun(msg)}
---@return R?
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

---Setup utility modules that require initialization
function Utils.setup()
   -- Setup modules by accessing them (triggers lazy loading)
   if Utils.format then
      Utils.format.setup()
   end
   if Utils.root then
      Utils.root.setup()
   end
   if Utils.lsp then
      Utils.lsp.setup()
   end
   if Utils.toggle then
      Utils.toggle.setup()
   end
   if Utils.keys then
      Utils.keys.setup()
   end
end

return Utils
