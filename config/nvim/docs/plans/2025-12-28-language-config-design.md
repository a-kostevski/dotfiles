# Language Configuration System Design

## Overview

Add configuration options to the language utility to disable all languages by default and only install specified ones, unless "all" is specified.

## Configuration

### File Location

`config/nvim/lua/kostevski/config/languages.lua`

### Format

```lua
return {
  -- "all" to load everything, or list of language names
  enabled = { "lua", "go", "python" },

  -- Per-language overrides merged into definitions
  overrides = {
    python = { lsp_server = "pyright" },
  },
}
```

### Defaults

If file doesn't exist or is empty:

```lua
{ enabled = { "lua" }, overrides = {} }
```

## Implementation

### New Functions in `utils/lang.lua`

| Function | Purpose |
|----------|---------|
| `get_config()` | Load and cache config with defaults |
| `is_enabled(name)` | Check if language is in enabled list or "all" |
| `get_overrides(name)` | Get override table for a language |
| `get_available()` | Scan `plugins/lang/` for available languages |
| `validate()` | Warn about unknown languages in enabled list |

### Modified `register()` Function

1. Early return `{}` if `is_enabled(def.name)` is false
2. Merge `get_overrides(def.name)` into definition before processing
3. Continue with existing logic

### Validation

- Runs once at startup via `vim.defer_fn(M.validate, 100)`
- Warns if enabled list contains names with no matching file
- Silent when `enabled = "all"`

## Behavior Matrix

| Config | Result |
|--------|--------|
| No file | Only `lua` loaded |
| `enabled = { "go" }` | Only `go` loaded |
| `enabled = "all"` | All languages loaded |
| `enabled = { "foo" }` | Warning: no `foo.lua` exists |
| `overrides = { go = {...} }` | Merged into go definition |

## Files Changed

| File | Change |
|------|--------|
| `config/languages.lua` | New file |
| `utils/lang.lua` | Add config functions, modify `register()` |
| `plugins/lang/*.lua` | No changes |
