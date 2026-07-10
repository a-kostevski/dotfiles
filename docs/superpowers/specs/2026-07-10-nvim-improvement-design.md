# Nvim Config Improvement Pass — Design

**Date:** 2026-07-10
**Scope:** `config/nvim/` in the dotfiles repo
**Goal:** Audit and fix real issues, remove dead code, cut startup time, polish completion, and round out the git workflow — in five phases, one commit each, staying within the current architecture (lazy.nvim + `kostevski.utils` framework).

## Context

The config was recently modernized for Neovim 0.11 (built-in LSP config, consolidated utils, −1,864 lines). The running Neovim is now **0.12.4**. Measured startup is **282ms**, dominated by eager plugin loading (`defaults = { lazy = false }` with ~60 plugins). The utils layer is ~4,000 lines, of which ~1,300 are dead. Completion is blink.cmp (already configured). Git tooling is gitsigns + lazygit, with no diff-review/conflict tool.

## Phase 1 — Audit & fix

- Run `luac -p` over all Lua files; fix syntax issues if any.
- Run `nvim --headless "+checkhealth" `-style checks and a startup with `--headless +qa`, capturing errors/warnings; fix real issues.
- Sweep for APIs deprecated in 0.11/0.12 and replace with current equivalents.
- Remove the leftover debug call `Utils.debug.dump(...)` in `lua/kostevski/plugins/conform.lua:63`.
- Verify the lang framework: `config/languages.lua` enables only `lua, terraform, cpp`, yet `plugins/lang/` contains ~10 language modules. Confirm disabled languages are fully inert (no specs registered, no LSP servers configured); fix if they leak.
- Spot-check keymaps that reference functions/modules for dangling references.

**Exit criteria:** clean headless startup, no deprecation warnings from our own code, `luac -p` passes.

## Phase 2 — Dead code removal

- Delete `lua/kostevski/utils/cache.lua` (379 lines, unused).
- Delete `lua/kostevski/utils/errors.lua` (334 lines, unused outside its own registration).
- Delete `lua/kostevski/utils/debug.lua` (399 lines; its only external caller is removed in Phase 1, and `errors.lua`'s internal use dies with `errors.lua`).
- Fold the two functions `notify.lua` uses from `Utils.strings` (`message`, `title`) into `notify.lua` as local helpers; delete `lua/kostevski/utils/strings.lua` (254 lines).
- Update the lazy-module registry in `lua/kostevski/utils/init.lua` to drop the deleted modules, and remove any related setup calls.
- Keep: `lang.lua`, `keys.lua`, `toggle.lua`, `root.lua`, `format.lua`, `ui.lua`, `plugin.lua`, `notify.lua`, `lsp/` — all verified in use.

**Exit criteria:** ~1,300 lines removed; clean headless startup; grep shows no references to deleted modules.

## Phase 3 — Startup overhaul

- Flip `defaults = { lazy = true }` in `lua/kostevski/config/lazy.lua`.
- Audit every plugin spec and assign a correct load trigger: `event` (e.g. `InsertEnter`, `LspAttach`, `VeryLazy`), `cmd`, `ft`, or `keys`. Colorscheme, lualine, and anything needed for first paint stay eager (`lazy = false`, `priority` where needed).
- Verify no functional regressions: plugins must still activate when their trigger fires (open file, run command, press keymap).
- Measure `--startuptime` before and after; record both numbers in the commit message.

**Target:** under ~120ms (from 282ms).
**Exit criteria:** startup target met or best-effort documented; all plugins verified to load on their triggers.

## Phase 4 — Completion polish

- **Keep LuaSnip**: custom Lua-format snippets in `config/nvim/snippets/` depend on it; converting to blink's native (VSCode-format) engine is not worth it.
- Validate `plugins/coding/blink.lua` against the current blink.cmp option schema; remove stale/renamed options (several `completion.trigger.*` keys look outdated) and anything that now matches blink defaults.
- Pin `version = "1.*"` instead of `"*"`.
- Confirm cmdline completion behavior is intentional and working.

**Exit criteria:** no blink config-validation warnings; completion, snippets, and cmdline completion verified working in a live session.

## Phase 5 — Git workflow

- Add `sindrets/diffview.nvim`: diff review (`:DiffviewOpen`), file history (`:DiffviewFileHistory`), and merge-conflict resolution, lazy-loaded on `cmd` with keymaps under the existing `<leader>g` prefix (registered in which-key).
- Review `plugins/editor/gitsigns.lua` keymaps: ensure hunk navigation (`]h`/`[h`), stage/reset/preview hunk, stage buffer, and blame are all mapped and non-conflicting.
- Gitsigns and lazygit remain unchanged otherwise.

**Exit criteria:** diffview opens/lazy-loads correctly; gitsigns hunk workflow complete; no keymap conflicts (which-key shows a coherent `<leader>g` group).

## Verification (every phase)

1. `luac -p` on all changed Lua files.
2. `nvim --headless +qa` exits clean (no errors/warnings from our config).
3. Manual smoke test in a real session (open files of the enabled languages, trigger the changed feature).
4. One commit per phase with a descriptive message.

## Out of scope

- Rewriting the utils/lang frameworks or restructuring around 0.12 natives.
- DAP changes (already configured; user did not request).
- New language support.
- Changes outside `config/nvim/` (except this doc).
