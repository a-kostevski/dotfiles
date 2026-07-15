# Audit fixes: Tier 1 + Tier 2 — design

Date: 2026-07-15
Scope: fix the 8 high-severity and 20 medium-severity findings from the 2026-07-15
four-way audit (zsh, nvim, install tooling, misc configs). Tier 3 (dead code,
deprecated APIs, macOS defaults drift) is explicitly out of scope.

## Decisions made with the user

- **Fix scope**: Tier 1 + Tier 2 only.
- **gitconfig.local**: adopt the copy-outside-the-repo workflow. The machine-local
  file lives at `~/.config/git/gitconfig.local` (a real file, not a symlink into
  the repo). The linker stays strict about gitignored files. Docs and
  `gitconfig.local.example` instructions change accordingly; on this machine the
  legacy symlink is replaced by a copy of its current content.
- **neotest**: remove the spec and its four dependencies. The lang system's
  `test_adapters` mechanism is untouched, so it can return when a language that
  uses it is enabled.

## Tier 1 fixes

1. **git identity linking** (`config/git/gitconfig.local.example`, docs): change
   the documented workflow to `cp gitconfig.local.example ~/.config/git/gitconfig.local`.
   `[include] path = gitconfig.local` in `config/git/config` already resolves
   relative to `~/.config/git/`, so no config change needed. Replace the local
   legacy symlink with a real copy.
2. **zsh history dir** (`config/zsh/rc.d/40-history.zsh`): `mkdir -p` the
   `$XDG_STATE_HOME/zsh` directory before setting HISTFILE, mirroring the cache-dir
   pattern in 30-completions.zsh.
3. **telescope trailing calls** (`plugins/telescope.lua:131,137`): drop the
   trailing `()` after `find_files(...)` in both `<a-i>` and `<a-h>` mappings.
4. **indent-guides toggle** (`utils/toggle.lua:210`): use
   `require("ibl.config").get_config(0)` instead of the nonexistent
   `require("ibl").config`.
5. **DAP fragment clobber** (`utils/lang.lua:291-309`): the lang-generated
   nvim-dap fragment must not set `config` (lazy.nvim scalar resolution lets it
   replace `coding/dap.lua`'s config). Convert to an `opts` function that
   registers adapters/configurations, leaving the base `config` intact.
6. **missing-manifest false success** (`install/manifest.sh`, `bootstrap.sh`):
   `link_configs` fails hard (non-zero exit, no "completed successfully") when
   `manifest_records` fails or the selected link set is empty.
7. **`dotfiles sync` dangling flag** (`bin/dotfiles:83-89`): error-and-exit when
   `-p/--profile/--config` has no value, matching bootstrap.sh's behavior.
8. **backup ordering** (`install/symlinks.sh:232-244`): rank backups by the
   timestamp embedded in the `.backup.%Y%m%d_%H%M%S[.N]` suffix (lexical sort +
   numeric `.N`), not by `-nt` content mtime.

## Tier 2 fixes

### zsh
- `.zprofile`: unset `HOMEBREW_PREFIX` when `$HOMEBREW_PREFIX/bin/brew` is not
  executable, so downstream `[[ -n ]]` guards mean what they say.
- `rc.d/20-exports.zsh`: drop the dangling bzip2 flag paths; guard remaining
  LDFLAGS/CPPFLAGS entries on the directories existing.
- `rc.d/30-completions.zsh`: make `list-colors` lazy with
  `zstyle -e ... 'reply=(${(s.:.)LS_COLORS})'` so it picks up LS_COLORS after
  dircolors runs.
- `rc.d/80-prompt.zsh`: give `unstagedstr` a visible glyph (`*`).
- `lib/docker.zsh`: split image IDs with `${(f)imgs}` in `drmid-fn`.
- `rc.d/71-plugins.zsh`: cache `fzf --zsh` output keyed on the fzf binary mtime,
  same pattern as the existing op-completion cache.

### nvim
- Deduplicate LSP init: `Utils.lsp.setup()` and the `Keys.on_attach`
  registration each run once (keep the `Utils.setup()`-driven path; remove the
  duplicates in `plugins/lsp/lspconfig.lua`).
- `utils/keys.lua` LspDetach: skip keymap deletion while another client is still
  attached to the buffer.
- `utils/ui.lua` `bufremove`: check `vim.bo[buf].modified` / `vim.fn.bufname(buf)`.
- `utils/format.lua` `enable`: act on `vim.b[buf]`, fix the swapped annotations.
- `plugins/lsp/lspconfig.lua` `automatic_enable`: switch from an exclude-list to
  an explicit allowlist of servers the lang system enables.
- Remove the neotest spec and its dependencies (`plugins/editor/neotest.lua`).
- `plugins/coding/mini-surround.lua`: delete the four mini.pairs options that
  mini.surround ignores; fix the misplaced `mode` key in the lazy `keys` list.

### misc configs
- `config/kitty/kitty.conf`: `hide_window_decorations yes`; keep the symbol_map
  but declare `font-symbols-only-nerd-font` as a [full] cask in packages.conf.
- `packages.conf`: add `karabiner-elements` cask under [full] (config is already
  linked in the full profile).
- `manifest.conf`: remove the dead `op` entry (directory is empty and untracked).
- Delete the empty `config/bat/themes/tokyonight-moon` file.

### install
- `bootstrap.sh`: guard the PROFILE_FILE write in normal mode the same way sync
  mode does, so `--config nvim` doesn't overwrite a stored profile.
- `install/homebrew.sh`: default `dot_root` like packages.sh does, so direct
  execution works as the header claims.
- `install/manifest.sh`: warn to stderr when an entry's src is missing instead of
  silently dropping it.

## Error handling & testing

- Shell changes must keep the tree shellcheck-warning-clean (`make .lint-shell`).
- Lua changes verified with `luac -p` (Lua 5.3/5.4-strict) and
  `stylua --check config/nvim`; match each file's existing indentation.
- Zsh changes verified with `zsh -n` per file.
- nvim behavior spot-checked headless (`nvim --headless`), remembering
  mason-lspconfig skips ensure_installed when headless.
- Install-tooling changes exercised with `./bootstrap.sh --dry-run`, a
  deliberately missing `MANIFEST_CONF`, and `bin/dotfiles sync -p` (must error,
  not hang).

## Commit strategy

Thematic commits: one per area (zsh, nvim, install, configs/packages, git
workflow docs), conventional-commit style matching repo history.
