# Audit Fixes (Tier 1 + Tier 2) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix the 8 high-severity and 20 medium-severity findings from the 2026-07-15 dotfiles audit (spec: `docs/superpowers/specs/2026-07-15-audit-fixes-design.md`).

**Architecture:** Seven thematic tasks — zsh, three nvim batches, install tooling, config/package manifests, and the git-identity workflow. Each task is independently verifiable and ends in one conventional commit.

**Tech Stack:** zsh, bash, Lua (Neovim/lazy.nvim), awk, kitty/git/brew config formats.

## Global Constraints

- Never modify files in `~/.config/` directly except in Task 7 step 3 (explicit machine migration). All other edits are to repo files.
- Shell tree must stay shellcheck-warning-clean: `make .lint-shell` passes.
- Lua must pass `luac -p` (Lua 5.4-strict: for-loop vars are const) and `stylua --check config/nvim`.
- When editing an nvim Lua file, match its existing indentation (some files are 3-space).
- Zsh files must pass `zsh -n`.
- The local interactive shell is zsh; run bash-specific checks via `bash -c`.
- Commit messages: conventional-commit style (`fix(zsh): ...`), matching repo history.

---

### Task 1: zsh fixes

**Files:**
- Modify: `config/zsh/rc.d/40-history.zsh:12`
- Modify: `config/zsh/.zprofile:17-28`
- Modify: `config/zsh/rc.d/20-exports.zsh:39-43`
- Modify: `config/zsh/rc.d/30-completions.zsh:71`
- Modify: `config/zsh/rc.d/80-prompt.zsh:4-8`
- Modify: `config/zsh/lib/docker.zsh:55`
- Modify: `config/zsh/rc.d/71-plugins.zsh:13-23`

**Interfaces:**
- Consumes: `command_exists` (defined in zsh lib, already available to rc.d files); `$XDG_STATE_HOME`, `$XDG_CACHE_HOME` (set in zshenv).
- Produces: nothing consumed by later tasks.

- [ ] **Step 1: Create the history directory before setting HISTFILE**

In `config/zsh/rc.d/40-history.zsh`, replace line 12:

```zsh
export HISTFILE=$XDG_STATE_HOME/zsh/zhistory
```

with:

```zsh
# zsh does not create HISTFILE's parent directory
[[ -d "$XDG_STATE_HOME/zsh" ]] || command mkdir -p -m 0700 "$XDG_STATE_HOME/zsh"
export HISTFILE=$XDG_STATE_HOME/zsh/zhistory
```

- [ ] **Step 2: Unset HOMEBREW_PREFIX when brew is absent**

In `config/zsh/.zprofile`, the block at lines 17-28 currently ends:

```zsh
   source "$brew_cache"
fi
```

Add an else-branch so the final block reads:

```zsh
# Cache brew shellenv for faster startup
if [ -x $HOMEBREW_PREFIX/bin/brew ]; then
   local brew_cache="$XDG_CACHE_HOME/zsh/brew_shellenv"
   local brew_bin="$HOMEBREW_PREFIX/bin/brew"

   # Regenerate cache if brew is newer than cache or cache doesn't exist
   if [[ ! -f "$brew_cache" ]] || [[ "$brew_bin" -nt "$brew_cache" ]]; then
      mkdir -p "${brew_cache:h}"
      "$brew_bin" shellenv > "$brew_cache"
   fi

   source "$brew_cache"
else
   # No brew here: downstream [[ -n $HOMEBREW_PREFIX ]] guards must not fire
   unset HOMEBREW_PREFIX
fi
```

- [ ] **Step 3: Guard compiler flags on kegs that exist; drop bzip2**

In `config/zsh/rc.d/20-exports.zsh`, replace lines 39-43:

```zsh
# Homebrew-specific compiler flags (only set if Homebrew is installed)
if [[ -n "$HOMEBREW_PREFIX" ]]; then
    export LDFLAGS="-L${HOMEBREW_PREFIX}/opt/zlib/lib -L${HOMEBREW_PREFIX}/opt/bzip2/lib -L${HOMEBREW_PREFIX}/opt/readline/lib"
    export CPPFLAGS="-I${HOMEBREW_PREFIX}/opt/zlib/include -I${HOMEBREW_PREFIX}/opt/bzip2/include -I${HOMEBREW_PREFIX}/opt/readline/include"
fi
```

with:

```zsh
# Homebrew-specific compiler flags, only for kegs that are actually present
# (bzip2 dropped: it was never declared in packages.conf)
if [[ -n "$HOMEBREW_PREFIX" ]]; then
    _ldflags=""
    _cppflags=""
    for _keg in zlib readline; do
        if [[ -d "$HOMEBREW_PREFIX/opt/$_keg" ]]; then
            _ldflags+="-L$HOMEBREW_PREFIX/opt/$_keg/lib "
            _cppflags+="-I$HOMEBREW_PREFIX/opt/$_keg/include "
        fi
    done
    if [[ -n "$_ldflags" ]]; then
        export LDFLAGS="${_ldflags% }"
        export CPPFLAGS="${_cppflags% }"
    fi
    unset _ldflags _cppflags _keg
fi
```

- [ ] **Step 4: Make completion list-colors lazy**

In `config/zsh/rc.d/30-completions.zsh`, replace line 71:

```zsh
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS:-}"
```

with:

```zsh
# -e: evaluate at completion time, after .zshrc's dircolors sets LS_COLORS
zstyle -e ':completion:*' list-colors 'reply=("${(s.:.)LS_COLORS}")'
```

- [ ] **Step 5: Make the unstaged indicator visible**

In `config/zsh/rc.d/80-prompt.zsh`, replace lines 4-8:

```zsh
zstyle ':vcs_info:*' enable git
zstyle ':vcs_info:*' formats ' %F{red}λ%f:%b%u%c'
zstyle ':vcs_info:*' actionformats ' %F{red}λ%f:%b|%a%u%c'
zstyle ':vcs_info:*' unstagedstr ' %F{blue}%f'
zstyle ':vcs_info:*' stagedstr ' %F{green}+%f'
```

with:

```zsh
zstyle ':vcs_info:*' enable git
# %u/%c only render when check-for-changes is on
zstyle ':vcs_info:*' check-for-changes true
zstyle ':vcs_info:*' formats ' %F{red}λ%f:%b%u%c'
zstyle ':vcs_info:*' actionformats ' %F{red}λ%f:%b|%a%u%c'
zstyle ':vcs_info:*' unstagedstr ' %F{blue}*%f'
zstyle ':vcs_info:*' stagedstr ' %F{green}+%f'
```

- [ ] **Step 6: Fix multi-image docker rmi**

In `config/zsh/lib/docker.zsh`, replace line 55:

```zsh
    docker rmi "$imgs"
```

with:

```zsh
    docker rmi ${(f)imgs}
```

- [ ] **Step 7: Cache fzf --zsh output**

In `config/zsh/rc.d/71-plugins.zsh`, replace lines 13-23:

```zsh
## fzf - load immediately as it's frequently used
if command_exists fzf; then
  # Capture once, then source only when generation succeeded.
  _fzf_init="$(fzf --zsh 2>/dev/null)"
  if [[ -n "$_fzf_init" ]]; then
    source <(print -r -- "$_fzf_init")
  elif [[ -f ~/.fzf.zsh ]]; then
    source ~/.fzf.zsh
  fi
  unset _fzf_init
fi
```

with:

```zsh
## fzf - load immediately as it's frequently used
if command_exists fzf; then
  # Cache the init script for faster startup (mirrors op_completion caching)
  local fzf_cache="$XDG_CACHE_HOME/zsh/fzf_init"
  local fzf_bin="$(command -v fzf)"
  if [[ ! -f "$fzf_cache" ]] || [[ "$fzf_bin" -nt "$fzf_cache" ]]; then
    mkdir -p "${fzf_cache:h}"
    fzf --zsh > "$fzf_cache" 2>/dev/null || : > "$fzf_cache"
  fi
  if [[ -s "$fzf_cache" ]]; then
    source "$fzf_cache"
  elif [[ -f ~/.fzf.zsh ]]; then
    source ~/.fzf.zsh
  fi
fi
```

- [ ] **Step 8: Verify syntax and behavior**

```bash
for f in config/zsh/rc.d/40-history.zsh config/zsh/.zprofile config/zsh/rc.d/20-exports.zsh config/zsh/rc.d/30-completions.zsh config/zsh/rc.d/80-prompt.zsh config/zsh/lib/docker.zsh config/zsh/rc.d/71-plugins.zsh; do zsh -n "$f" || echo "FAIL: $f"; done
```

Expected: no output (all pass). Then a live smoke test:

```bash
zsh -ic 'echo HIST=$HISTFILE; [[ -d ${HISTFILE:h} ]] && echo histdir-ok; echo LDFLAGS=$LDFLAGS' 2>&1 | tail -5
```

Expected: `histdir-ok` printed; LDFLAGS contains only existing keg paths (no bzip2).

- [ ] **Step 9: Commit**

```bash
git add config/zsh
git commit -m "fix(zsh): history dir creation, brew guards, lazy list-colors, prompt glyph, docker rmi, fzf cache"
```

---

### Task 2: nvim runtime-error fixes

**Files:**
- Modify: `config/nvim/lua/kostevski/plugins/telescope.lua:128-138`
- Modify: `config/nvim/lua/kostevski/utils/toggle.lua:203-221`
- Modify: `config/nvim/lua/kostevski/utils/lang.lua:290-310`

**Interfaces:**
- Consumes: nothing from other tasks.
- Produces: nothing consumed by later tasks.

- [ ] **Step 1: Drop the trailing calls in telescope helpers**

In `config/nvim/lua/kostevski/plugins/telescope.lua`, lines 128-138, remove the trailing `()` on both `find_files(...)` calls:

```lua
      local find_files_no_ignore = function()
        local action_state = require("telescope.actions.state")
        local line = action_state.get_current_line()
        require("telescope.builtin").find_files({ no_ignore = true, default_text = line })
      end

      local find_files_with_hidden = function()
        local action_state = require("telescope.actions.state")
        local line = action_state.get_current_line()
        require("telescope.builtin").find_files({ hidden = true, default_text = line })
      end
```

- [ ] **Step 2: Fix the indent-guides toggle**

In `config/nvim/lua/kostevski/utils/toggle.lua`, replace the `get` function of the `indent_guides` toggle (lines 205-212):

```lua
    get = function()
      local ok, ibl_config = pcall(require, "ibl.config")
      if not ok then
        return false
      end
      local config = ibl_config.get_config(0)
      return config and config.enabled
    end,
```

(The `set` function is unchanged.)

- [ ] **Step 3: Stop the lang DAP fragment from clobbering coding/dap.lua**

In `config/nvim/lua/kostevski/utils/lang.lua`, lines 290-310, change the fragment's `config` key to `opts` (lazy.nvim merges `opts` functions across fragments but resolves scalar `config` to the last fragment, silently discarding `coding/dap.lua`'s config):

```lua
  -- DAP configuration
  if def.dap then
    table.insert(specs, {
      "mfussenegger/nvim-dap",
      optional = true,
      -- opts (not config): a config here would replace coding/dap.lua's
      -- config in lazy.nvim's fragment resolution
      opts = function()
        local dap = require("dap")
        -- Apply DAP configurations
        for key, value in pairs(def.dap) do
          if key == "adapters" then
            for adapter_name, adapter_config in pairs(value) do
              dap.adapters[adapter_name] = adapter_config
            end
          elseif key == "configurations" then
            for ft, configs in pairs(value) do
              dap.configurations[ft] = configs
            end
          end
        end
      end,
    })
  end
```

- [ ] **Step 4: Verify**

```bash
luac -p config/nvim/lua/kostevski/plugins/telescope.lua config/nvim/lua/kostevski/utils/toggle.lua config/nvim/lua/kostevski/utils/lang.lua
stylua --check config/nvim/lua/kostevski/plugins/telescope.lua config/nvim/lua/kostevski/utils/toggle.lua config/nvim/lua/kostevski/utils/lang.lua
nvim --headless "+lua print(require('ibl.config') and 'ibl-config-ok')" +qa 2>&1 | tail -1
nvim --headless "+lua local p = require('lazy.core.config').plugins['nvim-dap']; print('dap-config-src:', type(p.config) == 'function' and debug.getinfo(p.config).source or tostring(p.config))" +qa 2>&1 | tail -1
```

Expected: `luac`/`stylua` silent; `ibl-config-ok` printed; the nvim-dap `config` source path points at `plugins/coding/dap.lua`, not `utils/lang.lua`.

- [ ] **Step 5: Commit**

```bash
git add config/nvim/lua/kostevski/plugins/telescope.lua config/nvim/lua/kostevski/utils/toggle.lua config/nvim/lua/kostevski/utils/lang.lua
git commit -m "fix(nvim): telescope picker calls, ibl toggle require, DAP fragment clobber"
```

---

### Task 3: nvim LSP init dedup and enable allowlist

**Files:**
- Modify: `config/nvim/lua/kostevski/plugins/lsp/lspconfig.lua:87-187`
- Modify: `config/nvim/lua/kostevski/utils/keys.lua:247-251`

**Interfaces:**
- Consumes: `Utils.lsp.setup()` is already called once from `utils/init.lua:367` during `Utils.setup()`; `Keys.setup()` (called from `Utils.setup()`) already registers `Keys.on_attach` via `Utils.lsp.on_attach` at `utils/keys.lua:241-245`. Those call sites stay.
- Produces: nothing consumed by later tasks.

- [ ] **Step 1: Remove the duplicate LSP setup and keymap registration**

In `config/nvim/lua/kostevski/plugins/lsp/lspconfig.lua`, the `config` function currently begins (lines 87-94):

```lua
    config = function(_, opts)
      Utils.format.register(Utils.lsp.formatter())
      Utils.lsp.on_attach(function(client, buffer)
        require("kostevski.utils.keys").on_attach(client, buffer)
      end)

      Utils.lsp.setup()
      Utils.lsp.on_dynamic_capability(require("kostevski.utils.keys").on_attach)
```

Replace with (keymap registration and `Utils.lsp.setup()` happen once in `Utils.setup()`/`Keys.setup()`):

```lua
    config = function(_, opts)
      Utils.format.register(Utils.lsp.formatter())
      -- Keys.on_attach registration and Utils.lsp.setup() run once from
      -- Utils.setup()/Keys.setup(); repeating them here double-registered
      -- keymaps and double-wrapped the rename handler
      Utils.lsp.on_dynamic_capability(require("kostevski.utils.keys").on_attach)
```

- [ ] **Step 2: Switch automatic_enable to an allowlist**

In the same file, the configure/enable block (lines 145-187) currently accumulates `mason_exclude`. Replace the whole block from `local mason_exclude = {}` through the `mason-lspconfig` setup call with:

```lua
      -- Allowlist of mason-managed servers configured below; anything else
      -- Mason has installed (strays, disabled languages) never auto-enables
      local enable = {}

      ---@return boolean? exclude automatic setup
      local function configure(server)
        local sopts = opts.servers[server]
        sopts = sopts == true and {} or (not sopts) and { enabled = false } or sopts --[[@as lazyvim.lsp.Config]]

        if sopts.enabled == false then
          return
        end

        local use_mason = sopts.mason ~= false and vim.tbl_contains(mason_all, server)
        local setup = opts.setup[server] or opts.setup["*"]
        if setup and setup(server, sopts) then
          return use_mason -- custom setup owns enabling; keep it out of the allowlist
        end
        vim.lsp.config(server, sopts) -- configure the server
        if use_mason then
          enable[#enable + 1] = server
        else
          vim.lsp.enable(server)
        end
        return use_mason
      end

      local install = vim.tbl_filter(configure, vim.tbl_keys(opts.servers))

      if have_mason then
        require("mason-lspconfig").setup({
          ensure_installed = vim.list_extend(install, Utils.plugin.opts("mason-lspconfig.nvim").ensure_installed or {}),
          automatic_enable = enable,
        })
      end
```

This also deletes the `get_disabled_servers()` exclusion loop (lines 172-180) and its comment — the allowlist makes it redundant. `require("kostevski.utils.lang")` must no longer be referenced in this function.

- [ ] **Step 3: Guard LspDetach against multi-client buffers**

In `config/nvim/lua/kostevski/utils/keys.lua`, replace the autocmd in `Keys.setup()` (lines 247-251):

```lua
  vim.api.nvim_create_autocmd("LspDetach", {
    callback = function(args)
      -- Keep buffer keymaps while another client is still attached
      for _, client in ipairs(vim.lsp.get_clients({ bufnr = args.buf })) do
        if client.id ~= args.data.client_id then
          return
        end
      end
      Keys.detach(args.buf)
    end,
  })
```

- [ ] **Step 4: Verify**

```bash
luac -p config/nvim/lua/kostevski/plugins/lsp/lspconfig.lua config/nvim/lua/kostevski/utils/keys.lua
stylua --check config/nvim/lua/kostevski/plugins/lsp/lspconfig.lua config/nvim/lua/kostevski/utils/keys.lua
grep -c "Utils.lsp.setup()" config/nvim/lua/kostevski/plugins/lsp/lspconfig.lua
nvim --headless +"lua vim.defer_fn(function() print('startup-ok') vim.cmd('qa!') end, 2000)" 2>&1 | tail -3
```

Expected: `luac`/`stylua` silent; grep prints `0`; headless startup prints `startup-ok` with no errors. Then an interactive check: open a Lua file in the repo, run `:lua vim.print(#vim.lsp.get_clients())` (lua_ls attaches), and confirm `grr`-style LSP keymaps exist exactly once via `:verbose nmap gd` (one definition, not two).

- [ ] **Step 5: Commit**

```bash
git add config/nvim/lua/kostevski/plugins/lsp/lspconfig.lua config/nvim/lua/kostevski/utils/keys.lua
git commit -m "fix(nvim): dedupe LSP init, allowlist automatic_enable, guard LspDetach keymap removal"
```

---

### Task 4: nvim behavior fixes and neotest removal

**Files:**
- Modify: `config/nvim/lua/kostevski/utils/ui.lua:157-169`
- Modify: `config/nvim/lua/kostevski/utils/format.lua:99-113`
- Modify: `config/nvim/lua/kostevski/plugins/coding/mini-surround.lua`
- Delete: `config/nvim/lua/kostevski/plugins/editor/neotest.lua`

**Interfaces:**
- Consumes: `Format.toggle` (`utils/format.lua:80-82`) calls `Format.enable(buf, ...)` — signature must stay `(buf, enable)`.
- Produces: nothing consumed by later tasks. The lang system's `test_adapters` fragment (`utils/lang.lua:313-327`) targets `"nvim-neotest/neotest"` with `optional = true`, so deleting the spec is safe.

- [ ] **Step 1: Make bufremove act on the target buffer**

In `config/nvim/lua/kostevski/utils/ui.lua`, replace lines 161-169:

```lua
  if vim.bo[buf].modified then
    local choice = vim.fn.confirm(("Save changes to %q?"):format(vim.fn.bufname(buf)), "&Yes\n&No\n&Cancel")
    if choice == 0 or choice == 3 then -- 0 for <Esc>/<C-c> and 3 for Cancel
      return
    end
    if choice == 1 then -- Yes
      vim.api.nvim_buf_call(buf, function()
        vim.cmd.write()
      end)
    end
  end
```

- [ ] **Step 2: Make Format.enable act on the target buffer**

In `config/nvim/lua/kostevski/utils/format.lua`, replace lines 99-113:

```lua
--- Enables or disables autoformatting for a buffer.
--- @param buf number: The buffer number (optional; global toggle when nil).
--- @param enable boolean: True to enable, false to disable.
function Format.enable(buf, enable)
  if enable == nil then
    enable = true
  end

  if buf then
    vim.b[buf].autoformat = enable
  else
    vim.g.autoformat = enable
    vim.b.autoformat = nil
  end
end
```

- [ ] **Step 3: Clean up mini-surround opts and keys**

Replace the full contents of `config/nvim/lua/kostevski/plugins/coding/mini-surround.lua` (the four leading opts were mini.pairs options that mini.surround ignores; the bare `mode = ...` sat at the wrong level of the keys list):

```lua
return {
  "echasnovski/mini.surround",
  event = "VeryLazy",
  opts = {
    mappings = {
      add = "gsa",
      delete = "gsd",
      find = "gsf",
      find_left = "gsF",
      highlight = "gsh",
      replace = "gsr",
      update_n_lines = "gsn",
    },
  },
  keys = {
    { "gsa", desc = "Add Surrounding", mode = { "n", "v" } },
    { "gsd", desc = "Delete Surrounding" },
    { "gsf", desc = "Find Right Surrounding" },
    { "gsF", desc = "Find Left Surrounding" },
    { "gsh", desc = "Highlight Surrounding" },
    { "gsr", desc = "Replace Surrounding" },
    { "gsn", desc = "Update n lines" },
  },
}
```

- [ ] **Step 4: Remove neotest**

```bash
git rm config/nvim/lua/kostevski/plugins/editor/neotest.lua
```

(Do not touch `nvim-dap-ui.lua` — its `nvim-neotest/nvim-nio` dependency is a standalone library, not neotest.)

- [ ] **Step 5: Verify**

```bash
luac -p config/nvim/lua/kostevski/utils/ui.lua config/nvim/lua/kostevski/utils/format.lua config/nvim/lua/kostevski/plugins/coding/mini-surround.lua
stylua --check config/nvim/lua/kostevski/utils/ui.lua config/nvim/lua/kostevski/utils/format.lua config/nvim/lua/kostevski/plugins/coding/mini-surround.lua
grep -rn "editor/neotest\|editor\.neotest" config/nvim/lua || echo no-refs
nvim --headless +"lua vim.defer_fn(function() print('startup-ok') vim.cmd('qa!') end, 2000)" 2>&1 | tail -3
```

Expected: checkers silent; `no-refs`; `startup-ok` with no errors (lazy.nvim will report the removed plugin as unused — run `:Lazy clean` interactively afterwards).

- [ ] **Step 6: Commit**

```bash
git add -A config/nvim/lua/kostevski
git commit -m "fix(nvim): bufremove/format target buffer, mini-surround opts; drop unreachable neotest"
```

---

### Task 5: install tooling fixes

**Files:**
- Modify: `bootstrap.sh:278-285` and `bootstrap.sh:449-451`
- Modify: `bin/dotfiles:77-90`
- Modify: `install/symlinks.sh:231-244`
- Modify: `install/homebrew.sh:8-12`
- Modify: `install/manifest.sh:100-120`

**Interfaces:**
- Consumes: `dot_error`/`dot_warning` from `install/lib.sh` (`dot_warning` prints to stdout — inside record-emitting functions it MUST be redirected `>&2`).
- Produces: `newest_backup_path` keeps its exact signature/output contract (prints one path, returns 1 if none) for `restore_newest_backup`.

- [ ] **Step 1: Fail hard when the link set is empty**

In `bootstrap.sh`, after the `links=` assignment block (line 276 ends the if/else) and before the `while IFS='|' read` loop, insert:

```bash
  if [[ -z "$links" ]]; then
    dot_error "No links selected (missing manifest or empty selection); aborting"
    exit 1
  fi
```

- [ ] **Step 2: Don't overwrite the stored profile in --config mode**

In `bootstrap.sh`, replace lines 449-451 (normal-mode branch):

```bash
    if [[ -z "$SYNC_CONFIG" && -z "$DRY_RUN" ]]; then
      printf '%s\n' "$PROFILE" >"$PROFILE_FILE"
    fi
```

- [ ] **Step 3: Error on dangling flag values in dotfiles sync**

In `bin/dotfiles` `cmd_sync`, replace the two case arms at lines 77-90:

```bash
      -p | --profile | minimal | standard | full | all)
        # Handle both --profile <name> and direct profile name
        if [[ "$1" =~ ^(minimal|standard|full|all)$ ]]; then
          profile="$1"
          shift
        else
          if [[ -z "${2:-}" ]]; then
            dot_error "Option $1 requires a value"
            return 2
          fi
          profile="$2"
          shift 2
        fi
        ;;
      --config)
        if [[ -z "${2:-}" ]]; then
          dot_error "Option $1 requires a value"
          return 2
        fi
        config="$2"
        shift 2
        ;;
```

- [ ] **Step 4: Rank backups by their name-embedded timestamp**

In `install/symlinks.sh`, replace `newest_backup_path` (lines 231-244):

```bash
# Print the newest backup for a destination, ranked by the timestamp (and
# numeric .N collision suffix) embedded in the backup name. mv preserves the
# original file's mtime, so -nt would rank by content age, not backup time.
newest_backup_path() {
    local dest="$1"
    local newest="" newest_key="" b key suffix
    for b in "$dest".backup.*; do
        [[ -e "$b" || -L "$b" ]] || continue
        key="${b##*.backup.}"   # 20260715_101530 or 20260715_101530.3
        if [[ "$key" == *.* ]]; then
            suffix="${key##*.}"
            [[ "$suffix" =~ ^[0-9]+$ ]] || suffix=0
            key="${key%%.*}.$(printf '%06d' "$suffix")"
        else
            key="${key}.000000"
        fi
        if [[ -z "$newest" || "$key" > "$newest_key" ]]; then
            newest="$b"
            newest_key="$key"
        fi
    done
    [[ -n "$newest" ]] || return 1
    printf '%s\n' "$newest"
}
```

- [ ] **Step 5: Let homebrew.sh run standalone**

In `install/homebrew.sh`, after the lib.sh source (line 8) and before the `packages_select` check, insert:

```bash
# Executed directly (not via bootstrap): derive the repo root ourselves
: "${dot_root:=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)}"
```

- [ ] **Step 6: Warn on manifest entries whose src is missing**

In `install/manifest.sh`, replace `_manifest_emit`'s file branch (lines 105-108):

```bash
  if [[ "$kind" == "file" ]]; then
    if [[ -f "$abs_src" ]]; then
      printf '%s|%s\n' "$abs_src" "$res_dest"
    else
      dot_warning "manifest: src not found: $src" >&2
    fi
    return 0
  fi
```

and guard the tree branch by inserting before the `while IFS= read -r f` loop:

```bash
  if [[ ! -d "$abs_src" ]]; then
    dot_warning "manifest: src not found: $src" >&2
    return 0
  fi
```

(The `>&2` is mandatory: `_manifest_emit`'s stdout is the link-record stream.)

- [ ] **Step 7: Verify**

```bash
make .lint-shell
MANIFEST_CONF=/nonexistent ./bootstrap.sh --dry-run; echo "exit=$?"
./bootstrap.sh --dry-run | tail -3; echo "exit=$?"
timeout 5 bin/dotfiles sync -p; echo "exit=$?"
bash -c 'source install/lib.sh; source install/symlinks.sh; d=$(mktemp -d)/f; touch "${d}.backup.20260101_000000" "${d}.backup.20260102_000000"; touch -t 202001010000 "${d}.backup.20260102_000000"; newest_backup_path "$d"'
bash install/homebrew.sh --help 2>&1 | head -2 || true
```

Expected: shellcheck clean; missing-manifest bootstrap prints the error and `exit=1`; normal dry-run still `exit=0`; `dotfiles sync -p` prints "requires a value" and exits 2 within the timeout (no hang); `newest_backup_path` prints the `20260102` backup despite its older mtime; homebrew.sh no longer dies with `dot_root: unbound variable`.

- [ ] **Step 8: Commit**

```bash
git add bootstrap.sh bin/dotfiles install/symlinks.sh install/homebrew.sh install/manifest.sh
git commit -m "fix(install): empty-link-set abort, sync arg validation, backup ordering, standalone homebrew.sh, missing-src warnings"
```

---

### Task 6: config and package manifest fixes

**Files:**
- Modify: `config/kitty/kitty.conf:37`
- Modify: `packages.conf` (full-only casks section, after line 108)
- Modify: `manifest.conf:37`
- Delete: `config/bat/themes/tokyonight-moon`

**Interfaces:**
- Consumes: packages.conf column format `name brew cask apt` (`-` = skip).
- Produces: nothing consumed by later tasks.

- [ ] **Step 1: Fix the kitty boolean**

In `config/kitty/kitty.conf`, replace line 37 (`hide_window_decorations 1` — kitty parses `1` as false):

```
hide_window_decorations yes
```

- [ ] **Step 2: Declare the missing casks**

In `packages.conf`, in the "full-only casks (macOS)" section, insert after the `font-hack-nerd-font` line:

```
font-symbols-only-nerd-font   -     font-symbols-only-nerd-font  -
karabiner-elements            -     karabiner-elements   -
```

(`font-symbols-only-nerd-font` backs kitty.conf's `Symbols Nerd Font Mono` symbol_map; `karabiner-elements` backs the karabiner config already linked in the full profile.)

- [ ] **Step 3: Remove the dead op manifest entry**

In `manifest.conf`, delete line 37 (`config/op` is empty and untracked, so the entry emits no links):

```
op            tree  config/op             {XDG_CONFIG}/op
```

- [ ] **Step 4: Delete the empty bat theme**

```bash
git rm config/bat/themes/tokyonight-moon
```

- [ ] **Step 5: Verify**

```bash
kitty +runpy "from kitty.config import load_config; o = load_config('config/kitty/kitty.conf'); print('decorations:', o.hide_window_decorations)" 2>/dev/null || echo "kitty not available; skip"
bash -c 'source install/lib.sh; source install/packages.sh; packages_select full cask | grep -E "karabiner|symbols"'
bash -c 'source install/lib.sh; source install/manifest.sh; manifest_links full macos | grep -c "config/op" || echo op-gone'
./bootstrap.sh --dry-run --profile full | tail -3; echo "exit=$?"
```

Expected: kitty reports decorations `1`/`True` (truthy); `packages_select` prints both new casks; `op-gone`; full-profile dry-run exits 0.

- [ ] **Step 6: Commit**

```bash
git add -A config/kitty packages.conf manifest.conf config/bat
git commit -m "fix(configs): kitty decorations bool, declare karabiner/nerd-symbols casks, drop dead op entry and empty bat theme"
```

---

### Task 7: git identity workflow

**Files:**
- Modify: `config/git/gitconfig.local.example:2`
- Machine migration (not a repo change): `~/.config/git/gitconfig.local`

**Interfaces:**
- Consumes: `config/git/config:164` (`[include] path = gitconfig.local`) resolves relative to `~/.config/git/`, so a real file there is picked up with no config change. README.md:284 already documents `cp config/git/gitconfig.local.example ~/.config/git/gitconfig.local` — only the example's own header contradicts it.
- Produces: nothing consumed by later tasks.

- [ ] **Step 1: Fix the example's instructions**

In `config/git/gitconfig.local.example`, replace line 2:

```
# Copy this file to gitconfig.local (same directory) and fill in your details.
```

with:

```
# Copy this file to ~/.config/git/gitconfig.local and fill in your details.
```

- [ ] **Step 2: Migrate this machine off the legacy symlink**

`~/.config/git/gitconfig.local` is currently a symlink into the repo (created by a pre-manifest installer; the manifest system can no longer produce or track it). Replace it with a real file:

```bash
target=$(readlink ~/.config/git/gitconfig.local)
rm ~/.config/git/gitconfig.local
mv "$target" ~/.config/git/gitconfig.local
```

- [ ] **Step 3: Verify**

```bash
[[ ! -L ~/.config/git/gitconfig.local && -f ~/.config/git/gitconfig.local ]] && echo migrated
[[ ! -e config/git/gitconfig.local ]] && echo repo-clean
git config user.email && git config user.name
```

Expected: `migrated`, `repo-clean`, and both `git config` calls still print the identity (the include resolves to the new real file).

- [ ] **Step 4: Commit**

```bash
git add config/git/gitconfig.local.example
git commit -m "docs(git): point gitconfig.local workflow at ~/.config/git (linker skips *.local by design)"
```

---

## Final verification (after all tasks)

```bash
make .lint-shell
luac -p $(git ls-files 'config/nvim/**/*.lua')
stylua --check config/nvim
for f in $(git ls-files 'config/zsh/**/*.zsh' 'config/zsh/zshenv' 'config/zsh/.zshrc' 'config/zsh/.zprofile'); do zsh -n "$f" || echo "FAIL: $f"; done
./bootstrap.sh --dry-run --profile full; echo "exit=$?"
nvim --headless +"lua vim.defer_fn(function() print('startup-ok') vim.cmd('qa!') end, 2000)" 2>&1 | tail -3
```

All clean, exit 0, `startup-ok`.
