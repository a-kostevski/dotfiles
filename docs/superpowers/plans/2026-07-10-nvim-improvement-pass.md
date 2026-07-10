# Nvim Config Improvement Pass — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Audit and fix the nvim config, remove ~1,300 lines of dead utils, cut startup from 282ms toward ~120ms via lazy-loading, polish blink.cmp, and add diffview.nvim for git diff review.

**Architecture:** All work stays inside `config/nvim/` within the existing lazy.nvim + `kostevski.utils` framework. Five tasks map 1:1 to the spec's five phases; each task ends with verification and a commit.

**Tech Stack:** Neovim 0.12.4, lazy.nvim, blink.cmp 1.x, LuaSnip, gitsigns, diffview.nvim, Lua 5.1 (`luac -p` available via `luajit -bl` fallback or `nvim -l`).

**Spec:** `docs/superpowers/specs/2026-07-10-nvim-improvement-design.md`

## Global Constraints

- Repo root: `/Users/antonkostevski/dev/repos/github.com/a-kostevski/dotfiles`; all Lua paths below are relative to `config/nvim/`.
- Never edit `~/.config/nvim` directly — edit the repo, symlinks propagate (per project CLAUDE.md).
- Keep LuaSnip; do NOT switch blink.cmp to its native snippet engine (custom Lua snippets in `snippets/` depend on LuaSnip).
- Keep modules: `utils/lang.lua`, `utils/keys.lua`, `utils/toggle.lua`, `utils/root.lua`, `utils/format.lua`, `utils/ui.lua`, `utils/plugin.lua`, `utils/notify.lua`, `utils/lsp/`.
- Verification for EVERY task before its commit:
  1. Syntax: `for f in $(git diff --cached --name-only -- 'config/nvim/*.lua'); do nvim -l -e "assert(loadfile('$f'))" 2>&1 || echo "FAIL: $f"; done` — no FAIL lines. (If `nvim -l -e` is unsupported, use `luac -p <file>`.)
  2. Clean start: `nvim --headless "+lua print('OK')" +qa 2>&1` — output is exactly `OK`, no error/warning lines.
  3. One commit per task, message prefixed `(nvim)`.
- Indentation in `config/nvim` is mixed (2 and 3 spaces per file) — match each file's existing style.

---

### Task 1: Audit & fix

**Files:**
- Modify: `lua/kostevski/plugins/conform.lua:62-66`
- Modify: any file surfaced by the audit (deprecated APIs, dangling references)
- Test: headless nvim runs (no test framework in this repo)

**Interfaces:**
- Consumes: nothing (first task).
- Produces: a clean baseline; `conform.lua` no longer references `Utils.debug` (Task 2 deletes that module).

- [ ] **Step 1: Capture the startup baseline (used again in Task 3)**

```bash
cd /Users/antonkostevski/dev/repos/github.com/a-kostevski/dotfiles/config/nvim
nvim --headless --startuptime /tmp/nvim-startup-baseline.log +qa
tail -1 /tmp/nvim-startup-baseline.log
```

Expected: a final line around `282ms` total. Save the number for Task 3's commit message.

- [ ] **Step 2: Syntax-check every Lua file**

```bash
cd /Users/antonkostevski/dev/repos/github.com/a-kostevski/dotfiles/config/nvim
for f in $(find . -name '*.lua'); do nvim -l -e "assert(loadfile('$f'))" >/dev/null 2>&1 || echo "SYNTAX FAIL: $f"; done
```

Expected: no output. Fix any failures before continuing.

- [ ] **Step 3: Run headless startup capturing all messages**

```bash
nvim --headless "+messages" +qa 2>&1
```

Expected: empty or benign output. Any `E`-prefixed errors, deprecation warnings, or stack traces from `kostevski.*` modules must be fixed. Record each finding.

- [ ] **Step 4: Sweep for deprecated APIs**

```bash
cd /Users/antonkostevski/dev/repos/github.com/a-kostevski/dotfiles/config/nvim
grep -rn "vim\.loop\b\|vim\.highlight\b\|nvim_buf_get_option\|nvim_buf_set_option\|nvim_win_get_option\|nvim_win_set_option\|nvim_get_option\b\|buf_get_clients\|vim\.tbl_islist\|vim\.tbl_add_reverse_lookup\|vim\.lsp\.get_active_clients\|sign_define" lua/
```

Replacements (apply to each hit):
- `vim.loop` → `vim.uv`
- `vim.highlight` → `vim.hl`
- `nvim_buf_get_option(b, o)` → `vim.api.nvim_get_option_value(o, { buf = b })`
- `nvim_buf_set_option(b, o, v)` → `vim.api.nvim_set_option_value(o, v, { buf = b })`
- `nvim_win_get_option(w, o)` → `vim.api.nvim_get_option_value(o, { win = w })`
- `vim.tbl_islist` → `vim.islist`
- `vim.lsp.get_active_clients` / `buf_get_clients` → `vim.lsp.get_clients`
- `vim.fn.sign_define` for diagnostics → `vim.diagnostic.config({ signs = { text = ... } })`

Expected: after edits, the grep returns nothing (or only hits inside third-party-mirroring comments).

- [ ] **Step 5: Remove the leftover debug dump in conform.lua**

In `lua/kostevski/plugins/conform.lua`, delete the entire `config` function so lazy.nvim falls back to its default `require("conform").setup(opts)`:

```lua
-- DELETE these lines (currently 62-66):
    config = function(_, opts)
      Utils.debug.dump({ formatters_by_ft = opts.formatters_by_ft, formatters = vim.tbl_keys(opts.formatters) })
      require("conform").setup(opts)
    end,
```

After deletion the spec must still contain `opts = function(...)` returning the opts table (lazy.nvim auto-calls `setup(opts)` when `config` is absent).

- [ ] **Step 6: Verify the lang framework is inert for disabled languages**

`config/languages.lua` enables only `{ "lua", "terraform", "cpp" }`. Check how `utils/lang.lua` consumes it, then verify with lazy's plugin list that disabled-language plugins (e.g. vimtex for tex, vim-rails for ruby) are either absent or `enabled = false`:

```bash
nvim --headless "+lua for _, p in ipairs(require('lazy').plugins()) do if p.name:match('vimtex') or p.name:match('rails') or p.name:match('markview') then print(p.name, vim.inspect(p.enabled)) end end" +qa 2>&1
```

Expected: each listed plugin prints `false` (or does not print at all). If a disabled language's plugins load anyway, fix the gating in `utils/lang.lua` (its registration must consult `require("kostevski.config.languages").enabled`) and re-run. If disabled languages ARE inert, note it and move on — no change.

- [ ] **Step 7: Check for dangling keymap references**

```bash
nvim --headless "+lua vim.cmd('silent! checkhealth which-key')" "+w! /tmp/wk-health.txt" +qa 2>&1; cat /tmp/wk-health.txt
```

Expected: no `ERROR` lines about overlapping/dangling mappings from our config. Fix real errors; ignore third-party warnings.

- [ ] **Step 8: Run global verification and commit**

Run the two Global Constraints checks, then:

```bash
cd /Users/antonkostevski/dev/repos/github.com/a-kostevski/dotfiles
git add config/nvim
git commit -m "(nvim) Audit pass: fix deprecated APIs, remove debug dump, verify lang gating"
```

---

### Task 2: Dead code removal

**Files:**
- Delete: `lua/kostevski/utils/cache.lua`, `lua/kostevski/utils/errors.lua`, `lua/kostevski/utils/debug.lua`, `lua/kostevski/utils/strings.lua`
- Modify: `lua/kostevski/utils/notify.lua` (inline the two string helpers), `lua/kostevski/utils/init.lua` (registry + annotations)

**Interfaces:**
- Consumes: Task 1 removed the only external `Utils.debug` caller (`conform.lua`).
- Produces: `Utils._modules` contains exactly: `notify, lsp, format, ui, plugin, toggle, root, keys, lang`. `notify.lua` gains two local functions: `format_message(msg: any): string?` and `format_title(title: string, level: integer): string`.

- [ ] **Step 1: Confirm no remaining references to the four modules**

```bash
cd /Users/antonkostevski/dev/repos/github.com/a-kostevski/dotfiles/config/nvim
grep -rn "utils\.cache\|utils\.errors\|utils\.debug\|utils\.strings\|Utils\.cache\|Utils\.errors\|Utils\.debug\|Utils\.strings" lua/ | grep -v "utils/init.lua" | grep -v "utils/notify.lua" | grep -v "^lua/kostevski/utils/\(cache\|errors\|debug\|strings\)\.lua"
```

Expected: no output. If anything prints, migrate that call site first (same inlining approach as notify below).

- [ ] **Step 2: Inline the two string helpers into notify.lua**

In `lua/kostevski/utils/notify.lua`, add near the top (after any existing locals, before the first function that uses them):

```lua
local MAX_TITLE_LENGTH = 50
local MAX_MESSAGE_SIZE = 1024

---Sanitize text: tabs to spaces, strip control chars except newlines
local function sanitize(text)
  if type(text) ~= "string" then
    text = tostring(text)
  end
  text = text:gsub("\t", "  ")
  text = text:gsub("[%c]", function(c)
    return c == "\n" and c or ""
  end)
  return text
end

---Format a message for display: handles tables, sanitizes, truncates
---@param msg any
---@return string?
local function format_message(msg)
  if not msg then
    return nil
  end
  local text
  if type(msg) == "table" then
    text = vim.islist(msg) and table.concat(msg, "\n") or vim.inspect(msg)
  else
    text = tostring(msg)
  end
  text = sanitize(text)
  if #text == 0 then
    return nil
  end
  if #text > MAX_MESSAGE_SIZE then
    text = text:sub(1, MAX_MESSAGE_SIZE) .. "..."
  end
  return text
end

---Format a title with a level indicator, truncated
---@param title string
---@param level integer
---@return string
local function format_title(title, level)
  local final_title = sanitize(title)
  local level_names = {
    [vim.log.levels.ERROR] = "ERROR",
    [vim.log.levels.WARN] = "WARN",
    [vim.log.levels.INFO] = "INFO",
    [vim.log.levels.DEBUG] = "DEBUG",
    [vim.log.levels.TRACE] = "TRACE",
  }
  final_title = string.format("[%s] %s", level_names[level] or "INFO", final_title)
  if #final_title > MAX_TITLE_LENGTH then
    final_title = final_title:sub(1, MAX_TITLE_LENGTH - 3) .. "..."
  end
  return final_title
end
```

Then replace the two call sites (currently ~lines 88-89 and 106-107):

```lua
-- BEFORE:
  local Utils = require("kostevski.utils")
  local formatted_msg = Utils.strings.message(msg)
-- AFTER:
  local formatted_msg = format_message(msg)
```

```lua
-- BEFORE:
    opts.title = Utils.strings.title(opts.title, level)
-- AFTER:
    opts.title = format_title(opts.title, level)
```

If the removed `local Utils = require("kostevski.utils")` line is used elsewhere in the same function, keep it; delete it only if now unused.

Note: `Strings.message` accepted an optional `progress` argument; no caller passes it (verified), so the inline version drops it.

- [ ] **Step 3: Delete the four modules**

```bash
cd /Users/antonkostevski/dev/repos/github.com/a-kostevski/dotfiles
git rm config/nvim/lua/kostevski/utils/cache.lua config/nvim/lua/kostevski/utils/errors.lua config/nvim/lua/kostevski/utils/debug.lua config/nvim/lua/kostevski/utils/strings.lua
```

- [ ] **Step 4: Clean the registry in utils/init.lua**

In `lua/kostevski/utils/init.lua`:

1. Remove these four lines from `Utils._modules`:
```lua
    debug = "kostevski.utils.debug",
    cache = "kostevski.utils.cache",
    strings = "kostevski.utils.strings",
    errors = "kostevski.utils.errors",
```
2. Remove the matching `---@field` annotations from the `---@class Utils` block:
```lua
---@field debug Debug Debug utilities for logging and inspection
---@field cache UtilsCache Caching utilities for performance optimization
---@field strings StringUtils String manipulation functions
---@field errors UtilsErrors Error handling and validation utilities
```
3. In the header comment (lines 1-13), delete the `Utils.P(value)`-adjacent mention of "debugging" if it names the debug module (`for debugging, LSP, formatting...` → `for LSP, formatting...`).

- [ ] **Step 5: Verify nothing references the deleted modules and notifications still work**

```bash
cd /Users/antonkostevski/dev/repos/github.com/a-kostevski/dotfiles/config/nvim
grep -rn "utils\.\(cache\|errors\|debug\|strings\)\|Utils\.\(cache\|errors\|debug\|strings\)" lua/
nvim --headless "+lua require('kostevski.utils').notify.info('hello from test', { title = 'Test' })" "+sleep 500m" +qa 2>&1
```

Expected: grep prints nothing; the notify command produces no error (a rendered toast is not observable headless — absence of errors is the pass condition). Also run both Global Constraints checks.

- [ ] **Step 6: Commit**

```bash
cd /Users/antonkostevski/dev/repos/github.com/a-kostevski/dotfiles
git add config/nvim
git commit -m "(nvim) Remove dead utils modules: cache, errors, debug, strings (-1300 lines)"
```

---

### Task 3: Startup overhaul (lazy-by-default)

**Files:**
- Modify: `lua/kostevski/config/lazy.lua:37-40`
- Modify: every plugin spec file lacking a load trigger (list in Step 2)

**Interfaces:**
- Consumes: clean baseline from Tasks 1-2; baseline startup number from Task 1 Step 1.
- Produces: `defaults = { lazy = true }`; every plugin spec has an explicit trigger (`event`/`cmd`/`ft`/`keys`) or explicit `lazy = false`.

- [ ] **Step 1: Flip the default in lazy.lua**

```lua
-- lua/kostevski/config/lazy.lua — BEFORE:
      defaults = {
         lazy = false,
         version = false,
      },
-- AFTER:
      defaults = {
         lazy = true,
         version = false,
      },
```

- [ ] **Step 2: Assign a trigger to every spec that lacks one**

With `lazy = true` by default, a spec with no trigger NEVER loads — every spec must be covered. Apply this table (specs that already have a suitable trigger keep it; verify each while editing):

| File | Plugin | Trigger to set |
|---|---|---|
| `plugins/colorscheme.lua` | catppuccin / tokyonight / nord | active scheme: `lazy = false, priority = 1000`; others: `lazy = true` (loaded on demand) |
| `plugins/ui/lualine.lua` | lualine | `event = "VeryLazy"` |
| `plugins/ui/notify.lua` | nvim-notify | `event = "VeryLazy"` — and ensure `vim.notify` is assigned in its `config` so early notifications still route once loaded |
| `plugins/ui/mini-starter.lua` | mini.starter | `lazy = false` (must be present at startup for the dashboard) |
| `plugins/ui/indent-line.lua` | indent-blankline | `event = { "BufReadPost", "BufNewFile" }` |
| `plugins/ui/kitty.lua` | vim-kitty | `ft = "kitty"` |
| `plugins/ui/splits.lua` | smart-splits | keep existing `keys`; add `lazy = true` if trigger missing |
| `plugins/ui/bufferline.lua` | bufferline | `event = "VeryLazy"` |
| `plugins/editor/gitsigns.lua` | gitsigns | `event = { "BufReadPre", "BufNewFile" }` |
| `plugins/editor/neo-tree.lua` | neo-tree (+nui, plenary deps) | `cmd = "Neotree"` plus its existing `<leader>ge`-style `keys` |
| `plugins/editor/neotest.lua` | neotest + adapters | keep existing trigger; adapters as `dependencies` (no own trigger needed) |
| `plugins/lsp/lspconfig.lua` | nvim-lspconfig, mason | `event = { "BufReadPre", "BufNewFile" }`; mason also `cmd = "Mason"` |
| `plugins/lsp/nvim-dap-ui.lua` | nvim-dap-ui | `lazy = true` (pulled in by dap) |
| `plugins/coding/dap.lua` | nvim-dap | `keys` for its debug mappings + `cmd = { "DapContinue", "DapToggleBreakpoint" }` |
| `plugins/coding/mini-pairs.lua` | mini.pairs | `event = "InsertEnter"` |
| `plugins/treesitter.lua` | nvim-treesitter | keep existing trigger (verify it is `event = { "BufReadPost", "BufNewFile" }`-equivalent) |
| `plugins/tools/hardtime.lua` | hardtime | `event = "VeryLazy"` |
| `plugins/tools/no-neckpain.lua` | no-neck-pain | `cmd = "NoNeckPain"` |
| `plugins/tools/undotree.lua` | undotree | `cmd = { "UndotreeToggle", "UndotreeShow" }` |
| `plugins/tools/zen.lua` | zen-mode | `cmd = "ZenMode"` |
| `plugins/tools/project.lua` | project.nvim | `event = "VeryLazy"` |
| `plugins/ai.lua` | claude-code.nvim | `cmd = { "ClaudeCode" }` + `keys` if any exist in the spec |
| `plugins/lang/*.lua` (bash, caddy, docker, javascript, lua, ruby, shell, terraform, toml, go, python, etc.) | per-language plugins | `ft = <language filetypes>` (e.g. go → `ft = "go"`, docker → `ft = "dockerfile"`, javascript → `ft = { "javascript", "typescript", "javascriptreact", "typescriptreact" }`); plugins the lang framework registers may already gate — verify per file |
| `plugins/conform.lua` | conform | keep existing trigger; if none: `event = "BufWritePre"` + `cmd = "ConformInfo"` |
| `plugins/lsp/lint.lua` | nvim-lint | keep existing; if none: `event = { "BufReadPost", "BufWritePost", "InsertLeave" }` |

Files already verified to have triggers (leave as-is unless broken): `blink.lua` (InsertEnter), `lazygit.lua`, `mini-ai.lua`, `mini-surround.lua`, `neogen.lua`, `grug-far.lua`, `mini-files.lua`, `todo.lua`, `trouble.lua`, `which-key.lua`, `telescope.lua`, `persistance.lua`, `lazydev.lua`, `mason-dap.lua`.

Example edit shape (gitsigns):

```lua
return {
   "lewis6991/gitsigns.nvim",
   event = { "BufReadPre", "BufNewFile" },
   opts = {
      ...
```

- [ ] **Step 3: Detect never-loading plugins**

```bash
nvim --headless "+lua local missing = {} for _, p in ipairs(require('lazy').plugins()) do local ok = p.lazy == false or p.event or p.cmd or p.ft or p.keys or (p._ and p._.dep) if not ok then table.insert(missing, p.name) end end print(#missing == 0 and 'ALL COVERED' or table.concat(missing, ', '))" +qa 2>&1
```

Expected: `ALL COVERED`. Any name printed needs a trigger or `lazy = false` — fix and re-run.

- [ ] **Step 4: Functional smoke test of lazy triggers**

Open a real (non-headless) nvim and verify, in order: dashboard renders (mini-starter), `:e some.lua` gets treesitter highlight + gitsigns column + LSP attach (`:LspInfo` shows lua_ls), insert mode shows blink completion and mini.pairs, `:Neotree` opens, `:Telescope find_files` opens, `<leader>gl` opens lazygit, statusline (lualine) and bufferline render after startup. Fix any plugin that fails to activate.

- [ ] **Step 5: Measure and compare startup**

```bash
nvim --headless --startuptime /tmp/nvim-startup-after.log +qa
tail -1 /tmp/nvim-startup-after.log
```

Expected: total under ~120ms. If above target, sort the log for the heaviest remaining `require`/`sourcing` entries, push those plugins to later events (`VeryLazy`), and re-measure. If a hard floor above 120ms remains (e.g. colorscheme + starter), record the final number — best-effort is acceptable per spec.

- [ ] **Step 6: Verify and commit (include before/after numbers)**

Run Global Constraints checks, then:

```bash
cd /Users/antonkostevski/dev/repos/github.com/a-kostevski/dotfiles
git add config/nvim
git commit -m "(nvim) Lazy-load by default: startup 282ms -> <measured>ms"
```

Replace `<measured>` with the Step 5 number.

---

### Task 4: Completion polish (blink.cmp)

**Files:**
- Modify: `lua/kostevski/plugins/coding/blink.lua`

**Interfaces:**
- Consumes: nothing new; blink already loads on `InsertEnter`.
- Produces: a schema-valid blink config pinned to `version = "1.*"`.

- [ ] **Step 1: Fetch the current blink.cmp option schema**

Use Context7 (per user's global rules): `resolve-library-id` for "blink.cmp", then `query-docs` asking "full configuration schema for completion.trigger, sources, fuzzy, and cmdline options in v1". Cross-check every key currently set in `blink.lua` (see spec list below) against the fetched docs.

- [ ] **Step 2: Pin the version**

```lua
-- BEFORE:
    version = "*",
-- AFTER:
    version = "1.*",
```

- [ ] **Step 3: Fix stale/misplaced options**

Known suspects to validate against the Step 1 docs and fix:

1. `fuzzy.use_proximity` — removed in v1; sorting is `fuzzy.sorts`. Replace:
```lua
-- BEFORE:
      fuzzy = {
        use_proximity = true,
        prebuilt_binaries = {
          download = true,
          force_version = nil,
        },
      },
-- AFTER:
      fuzzy = {
        sorts = { "score", "sort_text" },
        prebuilt_binaries = {
          download = true,
        },
      },
```
2. `sources.min_keyword_length` — in v1 this is per-provider. If docs confirm it is invalid at `sources` level, move it:
```lua
      sources = {
        default = { "lsp", "path", "snippets", "buffer" },
        providers = {
          buffer = { min_keyword_length = 3 },
        },
      },
```
3. `completion.trigger.*` keys — verify each of the five keys currently set exists in v1; delete any the docs don't list, and delete any whose set value equals the v1 default (the defaults win; less config is the point).
4. Delete any other option whose value matches the documented default (e.g. `enabled = true` on the spec, `scrollbar = true` if default).

- [ ] **Step 4: Runtime validation**

```bash
nvim --headless "+lua require('lazy').load({ plugins = { 'blink.cmp' } })" "+checkhealth blink.cmp" "+w! /tmp/blink-health.txt" +qa 2>&1; grep -iE "error|warn" /tmp/blink-health.txt
```

Expected: no config-validation errors (missing-binary warnings are acceptable if the prebuilt binary hasn't downloaded yet).

- [ ] **Step 5: Live smoke test**

In a real nvim session: open a Lua file, type `vim.a` — LSP completions appear with icons; accept with `<CR>`; `<Tab>` jumps through a snippet (type `func` in a Lua file, expand); `:` cmdline shows completions. All three must work.

- [ ] **Step 6: Verify and commit**

Run Global Constraints checks, then:

```bash
cd /Users/antonkostevski/dev/repos/github.com/a-kostevski/dotfiles
git add config/nvim/lua/kostevski/plugins/coding/blink.lua
git commit -m "(nvim) Polish blink.cmp: pin 1.x, fix stale options, trim defaults"
```

---

### Task 5: Git workflow (diffview.nvim)

**Files:**
- Create: `lua/kostevski/plugins/editor/diffview.lua`

**Interfaces:**
- Consumes: which-key group `<leader>g` = "Git" (exists at `plugins/editor/which-key.lua:124`). Taken keys: `<leader>gc` (Telescope commits), `<leader>gs` (Telescope status), `<leader>ge` (neo-tree git explorer), `<leader>gl` (LazyGit), `<leader>gh*` (gitsigns hunks).
- Produces: `:DiffviewOpen`/`:DiffviewFileHistory` and keymaps `<leader>gd`, `<leader>gq`, `<leader>gf`, `<leader>gF`.

- [ ] **Step 1: Create the diffview spec**

Create `lua/kostevski/plugins/editor/diffview.lua` (2-space indent, matching neighboring editor/ files):

```lua
return {
  "sindrets/diffview.nvim",
  cmd = { "DiffviewOpen", "DiffviewClose", "DiffviewFileHistory" },
  keys = {
    { "<leader>gd", "<cmd>DiffviewOpen<cr>", desc = "Diff View" },
    { "<leader>gq", "<cmd>DiffviewClose<cr>", desc = "Close Diff View" },
    { "<leader>gf", "<cmd>DiffviewFileHistory %<cr>", desc = "File History (current)" },
    { "<leader>gF", "<cmd>DiffviewFileHistory<cr>", desc = "Repo History" },
  },
  opts = {
    enhanced_diff_hl = true,
    view = {
      merge_tool = {
        layout = "diff3_mixed",
      },
    },
  },
}
```

- [ ] **Step 2: Confirm no keymap conflicts**

```bash
cd /Users/antonkostevski/dev/repos/github.com/a-kostevski/dotfiles/config/nvim
grep -rn '<leader>g[dqfF]"' lua/ | grep -v diffview.lua
```

Expected: no output. If a conflict appears, keep the existing mapping and pick the next free letter for diffview.

- [ ] **Step 3: Review gitsigns hunk coverage (verification-only)**

`plugins/editor/gitsigns.lua` already maps: `]h`/`[h` navigation, `<leader>ghs/ghS/ghr/ghR/ghu` stage/reset/undo, `<leader>ghp` preview, `<leader>ghb/ghB` blame, `<leader>ghd/ghD` diffthis, `ih` textobject. That satisfies the spec's hunk-workflow requirement. One fix while here: `gs.undo_stage_hunk` was deprecated in gitsigns 0.9+ — replace with a stage_hunk toggle-aware note only if `:checkhealth gitsigns` or startup shows a deprecation warning; otherwise leave untouched.

- [ ] **Step 4: Live smoke test**

In a real nvim session inside this repo: `<leader>gd` opens diffview (lazy-loads on the keymap), `<leader>gq` closes it, `<leader>gf` shows the current file's history, and which-key on `<leader>g` shows a coherent Git group including the four new entries.

- [ ] **Step 5: Verify and commit**

Run Global Constraints checks, then:

```bash
cd /Users/antonkostevski/dev/repos/github.com/a-kostevski/dotfiles
git add config/nvim/lua/kostevski/plugins/editor/diffview.lua
git commit -m "(nvim) Add diffview.nvim for diff review, file history, and merge conflicts"
```
