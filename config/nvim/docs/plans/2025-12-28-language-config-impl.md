# Language Configuration System Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add opt-in language loading with configurable enabled list and per-language overrides.

**Architecture:** New `config/languages.lua` defines enabled languages and overrides. The `utils/lang.lua` module checks this config in `register()` and returns empty specs for disabled languages.

**Tech Stack:** Neovim Lua, lazy.nvim plugin specs

---

## Task 1: Add Config Loading Functions

**Files:**
- Modify: `lua/kostevski/utils/lang.lua:26` (after `local M = {}`)

**Step 1: Add default config constant**

Add after line 26 (`local M = {}`):

```lua
-- Default configuration when no languages.lua exists
local DEFAULT_CONFIG = {
  enabled = { "lua" },
  overrides = {},
}
```

**Step 2: Add get_config function**

Add after the default config:

```lua
---Load and cache language configuration
---@return {enabled: string|string[], overrides: table}
function M.get_config()
  if M._config then
    return M._config
  end

  local ok, config = pcall(require, "kostevski.config.languages")
  if not ok or type(config) ~= "table" then
    config = vim.deepcopy(DEFAULT_CONFIG)
  end

  -- Ensure required fields exist
  config.enabled = config.enabled or DEFAULT_CONFIG.enabled
  config.overrides = config.overrides or {}

  M._config = config
  return config
end
```

**Step 3: Add is_enabled function**

```lua
---Check if a language is enabled
---@param name string Language name
---@return boolean
function M.is_enabled(name)
  local config = M.get_config()

  if config.enabled == "all" then
    return true
  end

  if type(config.enabled) == "table" then
    return vim.tbl_contains(config.enabled, name)
  end

  return false
end
```

**Step 4: Add get_overrides function**

```lua
---Get configuration overrides for a language
---@param name string Language name
---@return table
function M.get_overrides(name)
  local config = M.get_config()
  return config.overrides and config.overrides[name] or {}
end
```

**Step 5: Verify syntax**

Run: `luac -p lua/kostevski/utils/lang.lua`
Expected: No output (success)

**Step 6: Commit**

```bash
git add lua/kostevski/utils/lang.lua
git commit -m "(nvim) Add language config loading functions"
```

---

## Task 2: Add Validation Functions

**Files:**
- Modify: `lua/kostevski/utils/lang.lua` (after get_overrides)

**Step 1: Add get_available function**

```lua
---Get list of available language configurations
---@return string[]
function M.get_available()
  if M._available then
    return M._available
  end

  local lang_dir = vim.fn.stdpath("config") .. "/lua/kostevski/plugins/lang"
  local files = vim.fn.glob(lang_dir .. "/*.lua", false, true)

  M._available = {}
  for _, file in ipairs(files) do
    local name = vim.fn.fnamemodify(file, ":t:r")
    table.insert(M._available, name)
  end

  return M._available
end
```

**Step 2: Add validate function**

```lua
---Validate configuration and warn about unknown languages
function M.validate()
  local config = M.get_config()

  if config.enabled == "all" then
    return
  end

  if type(config.enabled) ~= "table" then
    return
  end

  local available = M.get_available()
  for _, name in ipairs(config.enabled) do
    if not vim.tbl_contains(available, name) then
      vim.notify(
        string.format("[lang] '%s' is enabled but no config exists in plugins/lang/", name),
        vim.log.levels.WARN
      )
    end
  end
end
```

**Step 3: Verify syntax**

Run: `luac -p lua/kostevski/utils/lang.lua`
Expected: No output (success)

**Step 4: Commit**

```bash
git add lua/kostevski/utils/lang.lua
git commit -m "(nvim) Add language validation functions"
```

---

## Task 3: Modify register() Function

**Files:**
- Modify: `lua/kostevski/utils/lang.lua:67` (the register function)

**Step 1: Add early return for disabled languages**

At the start of `register()` function (after `local specs = {}`), add:

```lua
  -- Check if language is enabled
  if not M.is_enabled(def.name) then
    return {}
  end

  -- Merge any overrides from config
  local overrides = M.get_overrides(def.name)
  if next(overrides) then
    def = vim.tbl_deep_extend("force", def, overrides)
  end
```

**Step 2: Verify syntax**

Run: `luac -p lua/kostevski/utils/lang.lua`
Expected: No output (success)

**Step 3: Commit**

```bash
git add lua/kostevski/utils/lang.lua
git commit -m "(nvim) Add enabled check and overrides to register()"
```

---

## Task 4: Add Deferred Validation Call

**Files:**
- Modify: `lua/kostevski/utils/lang.lua` (at end of file, before `return M`)

**Step 1: Add deferred validation**

Add before `return M`:

```lua
-- Validate configuration after startup
vim.defer_fn(function()
  M.validate()
end, 100)
```

**Step 2: Verify syntax**

Run: `luac -p lua/kostevski/utils/lang.lua`
Expected: No output (success)

**Step 3: Commit**

```bash
git add lua/kostevski/utils/lang.lua
git commit -m "(nvim) Add deferred language config validation"
```

---

## Task 5: Create Default Configuration File

**Files:**
- Create: `lua/kostevski/config/languages.lua`

**Step 1: Create the configuration file**

```lua
-- Language Configuration
-- Controls which language support modules are loaded
--
-- Options:
--   enabled = "all"              -- Load all available languages
--   enabled = { "lua", "go" }    -- Load only specified languages
--
--   overrides = {                -- Per-language configuration overrides
--     python = { lsp_server = "pyright" },
--   }

return {
  enabled = { "lua" },
  overrides = {},
}
```

**Step 2: Verify syntax**

Run: `luac -p lua/kostevski/config/languages.lua`
Expected: No output (success)

**Step 3: Commit**

```bash
git add lua/kostevski/config/languages.lua
git commit -m "(nvim) Add default language configuration file"
```

---

## Task 6: Manual Testing

**Step 1: Test default config (only lua)**

1. Start Neovim: `nvim`
2. Run: `:Lazy`
3. Verify: Only lua-related language plugins loaded (lua_ls, stylua)
4. Open a Go file: `nvim test.go`
5. Verify: No gopls, no go formatters active

**Step 2: Test enabling go**

1. Edit `lua/kostevski/config/languages.lua`:
   ```lua
   return {
     enabled = { "lua", "go" },
     overrides = {},
   }
   ```
2. Restart Neovim
3. Verify: gopls and go tools now load

**Step 3: Test "all" mode**

1. Edit config: `enabled = "all"`
2. Restart Neovim
3. Verify: All language plugins load

**Step 4: Test invalid language warning**

1. Edit config: `enabled = { "lua", "nonexistent" }`
2. Restart Neovim
3. Verify: Warning message about 'nonexistent'

**Step 5: Test overrides**

1. Edit config:
   ```lua
   return {
     enabled = { "lua", "python" },
     overrides = {
       python = { lsp_server = "pyright" },
     },
   }
   ```
2. Restart Neovim, open `.py` file
3. Verify: `:LspInfo` shows pyright (not basedpyright)

---

## Task 7: Final Commit

**Step 1: Verify all changes**

Run: `git status`
Expected: All changes committed

**Step 2: Run final syntax check**

Run: `luac -p lua/kostevski/utils/lang.lua lua/kostevski/config/languages.lua`
Expected: No output (success)

**Step 3: Create summary commit if needed**

If any uncommitted changes remain:
```bash
git add -A
git commit -m "(nvim) Complete language configuration system"
```
