-- ============================================================================
-- Utilities Module - Central hub for all utility functions and modules
-- ============================================================================
-- This module provides a lazy-loading mechanism for all utility submodules,
-- ensuring minimal startup overhead while providing comprehensive functionality
-- for LSP, formatting, UI, plugins, and more.
--
-- Usage:
--   local Utils = require("kostevski.utils")
--   Utils.P(value)             -- Pretty print
--   Utils.lsp.format()         -- LSP formatting (lazy loaded)
--   Utils.toggle.create(...)   -- Create toggles (lazy loaded)
-- ============================================================================

---@class Utils Main utilities interface with lazy-loaded submodules
---@field notify NotifyUtils Notification system for user feedback
---@field lsp LspUtils LSP integration utilities (capabilities, formatting, diagnostics)
---@field format Format Code formatting utilities
---@field ui UiUtils UI helper functions for windows, buffers, and displays
---@field plugin PluginUtils Plugin management and lazy.nvim helpers
---@field toggle ToggleUtils Feature toggle system with keybindings
---@field root Root Project root detection utilities
---@field keys Keys Keymap management utilities
---@field lang LangUtils Language-specific configuration registration
---@field _loaded table<string, boolean> Internal: Tracks loaded modules
---@field _modules table<string, string> Internal: Module name to path mapping
local Utils = {
  _loaded = {},
  _modules = {
    notify = "kostevski.utils.notify",
    lsp = "kostevski.utils.lsp",
    format = "kostevski.utils.format",
    ui = "kostevski.utils.ui",
    plugin = "kostevski.utils.plugin",
    toggle = "kostevski.utils.toggle",
    root = "kostevski.utils.root",
    keys = "kostevski.utils.keys",
    lang = "kostevski.utils.lang",
  },
}

-- Metatable implementation for lazy loading submodules
-- Modules are only loaded when first accessed, reducing startup time
setmetatable(Utils, {
  __index = function(self, key)
    -- Check if it's a registered module that needs lazy loading
    local module_path = self._modules[key]
    if module_path and not self._loaded[key] then
      -- Attempt to lazy load the module
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

---Recursively flatten a nested table structure into a single-level list
---
---Takes any nested table structure and extracts all non-table values into
---a flat array. Useful for processing deeply nested data structures or
---collecting all leaf values from a tree-like table.
---
---@param item any The value to flatten (table or primitive)
---@param result? table Optional accumulator table for recursive calls
---@return table flattened_list A flat list containing all non-table values
---
---@usage
---  Utils.flatten({1, {2, 3}, {4, {5, 6}}})  -- {1, 2, 3, 4, 5, 6}
---  Utils.flatten({a = 1, b = {c = 2, d = 3}})  -- {1, 2, 3}
function Utils.flatten(item, result)
  result = result or {}
  if type(item) == "table" then
    for _, v in pairs(item) do
      Utils.flatten(v, result)
    end
  else
    result[#result + 1] = item
  end
  return result
end

---Remove duplicate values from a list while preserving order
---
---Returns a new list with only the first occurrence of each value.
---Order of first occurrences is preserved.
---
---@generic T
---@param list T[] The input list that may contain duplicates
---@return T[] deduplicated_list A new list with duplicates removed
---
---@usage
---  Utils.dedup({1, 2, 2, 3, 1})  -- {1, 2, 3}
---  Utils.dedup({"a", "b", "a"})  -- {"a", "b"}
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

---Normalize a file path to a consistent format
---
---Performs the following normalizations:
---  - Expands ~ to home directory
---  - Converts backslashes to forward slashes
---  - Removes duplicate slashes
---  - Removes trailing slash (except for root)
---
---@param path string The file path to normalize
---@return string normalized_path The normalized path
---
---@usage
---  Utils.norm("~/config//file.lua")     -- "/home/user/config/file.lua"
---  Utils.norm("C:\\Users\\name\\file")  -- "C:/Users/name/file"
function Utils.norm(path)
  if not path or path == "" then
    return ""
  end

  -- Replace ~ with the home directory
  if path:sub(1, 1) == "~" then
    local home = vim.uv.os_homedir()
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

---Pretty print a value using vim.inspect and return it (for chaining)
---
---Useful for debugging - prints the value in a human-readable format
---and returns it so it can be used in expressions.
---
---@param value any The value to pretty print
---@return any value The same value that was passed in (for chaining)
---
---@usage
---  Utils.P(vim.lsp.get_clients())  -- Print and inspect LSP clients
---  local result = Utils.P(some_function())  -- Print and capture result
function Utils.P(value)
  print(vim.inspect(value))
  return value
end

---Reload a Lua module by clearing it from package.loaded
---
---Uses plenary.reload if available for better reloading, otherwise falls back
---to manually clearing package.loaded. Useful during development for testing
---changes without restarting Neovim.
---
---@param name string The module name to reload (e.g., "kostevski.utils")
---@return any module The reloaded module
---
---@usage
---  Utils.RELOAD("kostevski.config")  -- Reload config module
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

---Reload and require a module (convenience wrapper for RELOAD)
---
---Shorthand for reloading and requiring a module. Useful for rapid development.
---
---@param name string The module name to reload and require
---@return any module The reloaded module
---
---@usage
---  local config = Utils.R("kostevski.config")  -- Reload and get module
function Utils.R(name)
  Utils.RELOAD(name)
  return require(name)
end

---Create a debounced version of a function
---
---Returns a new function that delays invoking `fn` until after `ms` milliseconds
---have elapsed since the last time it was invoked. Useful for rate-limiting
---expensive operations like autocomplete or file system operations.
---
---@param ms number Milliseconds to wait before executing
---@param fn function The function to debounce
---@return function debounced_fn A debounced version of the function
---
---@usage
---  local save = Utils.debounce(1000, function() vim.cmd.write() end)
---  vim.api.nvim_create_autocmd("TextChanged", { callback = save })
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

---Initialize all utility modules that require setup
---
---Triggers lazy loading and setup for modules that need initialization:
---  - format: Code formatting configuration
---  - root: Project root detection
---  - lsp: LSP handlers and configurations
---  - toggle: Feature toggles and keybindings
---  - keys: Keymap management
---
---Should be called during Neovim initialization (typically in init.lua)
---
---@usage
---  -- In init.lua
---  require("kostevski.utils").setup()
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
  -- Utils.toggle.setup() is NOT called here: it creates <leader> keymaps, and
  -- Utils.setup() runs before options.lua sets mapleader. config/init.lua
  -- calls it after the config modules load.
  if Utils.keys then
    Utils.keys.setup()
  end
end

return Utils
