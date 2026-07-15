# Dotfiles Audit — 2026-07-15

> **Status:** Tier 1 and Tier 2 fixed and merged in `4e76c31` (branch `audit-fixes`,
> 2026-07-16; spec `docs/superpowers/specs/2026-07-15-audit-fixes-design.md`, plan
> `docs/superpowers/plans/2026-07-15-audit-fixes.md`). Tier 3 fixed on branch
> `audit-tier3` (2026-07-16); the only item left as-is is the dangling `includeIf`
> in the machine-local, untracked `gitconfig.local` (harmless — git ignores
> missing include paths). Line numbers below refer to the pre-fix tree (`1fabfaf`).

Four parallel audits: zsh (18 findings), nvim (43), install tooling (14), misc tool configs (14). Every finding was verified against the actual code by the auditing agent (quoted lines, `luac -p`, shellcheck, kitty's own parser, empirical repro for the shell bugs).

## Tier 1 — Real bugs that bite now (high severity)

| # | Area | File | Problem |
|---|------|------|---------|
| 1 | git | `config/git/config:164` | `gitconfig.local` matches `*.local` in `.gitignore`, and the linker skips gitignored files — so on a fresh machine the documented workflow produces a file that never gets linked. Git identity, SSH signing, and delta silently don't load. The current machine only works via a legacy symlink the manifest system no longer tracks. |
| 2 | zsh | `config/zsh/rc.d/40-history.zsh:12` | `HISTFILE=$XDG_STATE_HOME/zsh/zhistory` but nothing ever creates that directory; zsh won't create it, so history saving fails on a fresh install. |
| 3 | nvim | `plugins/telescope.lua:131,137` | `<a-i>` and `<a-h>` in-picker mappings call the picker result with a trailing `()` — pickers return `nil`, so both keys throw "attempt to call a nil value". |
| 4 | nvim | `utils/toggle.lua:210` | `<leader>ti` (indent guides toggle) indexes `require("ibl").config`, which doesn't exist — raises an error. Should be `require("ibl.config").get_config(0)`. |
| 5 | nvim | `utils/lang.lua:291-309` | The lang system's DAP fragment sets `config` on the shared `nvim-dap` spec; lazy.nvim resolves scalar `config` to the last fragment, so the enabled cpp language silently discards `coding/dap.lua`'s config (signs, DapStoppedLine, mason-nvim-dap setup). C++ debugging is degraded. |
| 6 | install | `install/manifest.sh:54` + `bootstrap.sh:275` | Missing/unreadable `manifest.conf` is swallowed: bootstrap prints an error but exits 0 with "Bootstrap completed successfully!" having linked nothing. |
| 7 | install | `bin/dotfiles:83-89` | `dotfiles sync -p` / `--profile` / `--config` with no value infinite-loops (failed `shift 2` never consumes the arg). |
| 8 | install | `install/symlinks.sh:232-244` | "Newest backup" is picked with `-nt`, but `mv` preserves content mtime — restore can pick the wrong (older) backup. Should rank by the timestamp in the `.backup.YYYYmmdd_HHMMSS` suffix. |

## Tier 2 — Correctness & behavior (medium)

### zsh
- `.zprofile:8-14` — `HOMEBREW_PREFIX` set unconditionally, defeating every downstream `[[ -n $HOMEBREW_PREFIX ]]` guard; on brew-less machines exports LDFLAGS/CPPFLAGS pointing at nonexistent dirs.
- `rc.d/20-exports.zsh:41-42` — LDFLAGS reference `opt/bzip2` but bzip2 isn't in packages.conf (dangling even on full install).
- `rc.d/30-completions.zsh:71` — `list-colors` bakes in LS_COLORS before dircolors runs (end of .zshrc), so completion coloring is empty in fresh login shells.
- `rc.d/80-prompt.zsh:7` — `unstagedstr` is `%F{blue}%f` with no glyph between the color codes — the unstaged indicator is literally invisible.
- `lib/docker.zsh:55` — `docker rmi "$imgs"` passes all dangling image IDs as one argument; fails with >1 image. Use `${(f)imgs}`.
- `rc.d/71-plugins.zsh:16` — `fzf --zsh` forked every startup while op/brew are cached; cache it the same way.

### nvim
- `plugins/lsp/lspconfig.lua:93` — `Utils.lsp.setup()` runs twice → rename handler double-wrapped → "Renamed N occurrences" notifies twice.
- `plugins/lsp/lspconfig.lua:89-91` + `utils/keys.lua:241-245` — LSP keymaps registered on attach twice.
- `utils/keys.lua:228-239` — `LspDetach` deletes all buffer LSP keymaps even when another client is still attached.
- `utils/ui.lua:161-162` — `bufremove(buf)` checks the *current* buffer's modified state, not `buf`'s — bufferline close can silently discard changes.
- `utils/format.lua:102-113` — `Format.enable(buf, ...)` sets `vim.b.autoformat` on the current buffer regardless of `buf`.
- `plugins/lsp/lspconfig.lua:176-180` — `automatic_enable` excludes only known disabled servers; stray Mason installs (biome, dockerls, docker-compose) auto-enable with default configs. Switch to allowlist.
- `plugins/editor/neotest.lua` — neotest + 4 deps installed and configured but unreachable (lazy=true, no cmd/event, keys commented out, loaders only in disabled languages).
- `plugins/coding/mini-surround.lua:4-8` — four mini.pairs options pasted into mini.surround where they're silently ignored; `mode` at wrong level in keys.

### misc configs
- `config/kitty/kitty.conf:37` — `hide_window_decorations 1` parses to false in kitty (`to_bool('1') → False`); decorations are not hidden. Use `yes`.
- `config/kitty/kitty.conf:10` — `Symbols Nerd Font Mono` symbol_map references a font no package installs and that isn't on this machine.
- `manifest.conf:38` — karabiner config linked in full profile but no `karabiner-elements` cask in packages.conf.
- `manifest.conf:37` — `op` entry points at an empty, untracked directory; emits no links.
- `config/bat/themes/tokyonight-moon` — 0-byte theme file, wrong extension, never activated, no `bat cache --build` step.

### install
- `bootstrap.sh:449-451` — `./bootstrap.sh --config nvim` overwrites the stored profile with default `minimal` (sync mode guards this; normal mode doesn't).
- `install/homebrew.sh:11,45` — dies with `dot_root: unbound variable` when executed directly, contradicting its own header.
- `install/manifest.sh:105-107` — a manifest entry whose src is missing is silently skipped (no warning).

## Tier 3 — Cleanup, dead code, drift (low)

### zsh
- `lib/platform.zsh` — `PLATFORM_OS`/`PLATFORM_ARCH` (2 uname forks/startup) and 6 helper functions never called; 60-aliases reimplements the clipboard/open logic inline.
- `profile.d/10-path.zsh` — `go env GOROOT` fork that never uses its result; hardcoded pnpm/npm paths instead of `$PNPM_HOME`/`$XDG_DATA_HOME`; `postgresql@16` path for a package never installed.
- `rc.d/60-aliases.zsh` — unguarded `zotify` alias; `manpath` alias shadows manpath(1).
- `rc.d/90-window.zsh:11` — screen title branch: stray `$3`, and matches only literal `screen` (not `screen-256color`/`tmux-*`).
- `.zprofile:3-5` — empty exported MANPATH on Ubuntu overrides man-db's path derivation.
- `rc.d/50-keybindings.zsh` — unused `keys` array entries.
- Platform detection done 4 different ways across zshenv/.zprofile/profile.d/lib.

### nvim
- Dead Utils code: `Utils.merge`, `is_list`, `create_undo`, `try`, `Keys.map`, `Format.formatexpr/toggle`, `toggle.get`, `root.git/clear_cache`, `Lsp.has`, notify config fields, `ui.spinner`, icon groups.
- `tools/project.lua:22` and `editor/neo-tree.lua:13` — wrong plugin names ("telescope"/"neo-tree" vs actual "*.nvim") make the guards no-ops.
- `editor/neo-tree.lua:187` — `icons.git.renamed` doesn't exist (field is `rename`) → nil symbol.
- `coding/mini-ai.lua:103-107` — computed desc discarded; which-key shows "with ws" on inside-objects.
- `editor/gitsigns.lua` — deprecated `next_hunk`/`prev_hunk`/`undo_stage_hunk` APIs; hard `require("which-key")` forces early load.
- `config/lazy.lua:26` — synchronous `git rev-parse` every startup to verify the lazy.nvim pin.
- `treesitter.lua:47-56` — FileType autocmd acts on current buffer instead of `args.buf`; no augroup.
- Latent (disabled-language) bugs: caddy registered as "Caddyfile" so it can never enable; bash/shell dead inline LSP configs + double-format on_attach in `lsp/bashls.lua`; texlab module-scope autocmd; markdown prettier vs prettierd mismatch; ruby `erb` parser should be `embedded_template`.
- Disabled catppuccin/nord specs carrying ~40 lines; undotree's unused plenary dep; which-key descs for nonexistent `<BS>`/`<c-space>` mappings; telescope `root = false` LazyVim-ism; mini-starter no-op format hook; NoNeckPain toggle state buffer-local vs tab-scoped.

### install / misc
- `Makefile` — DRY_RUN advertised globally but ignored by uninstall/clean/backup.
- `bin/dotfiles:42-44` — MANIFEST_FILE/PROFILE_FILE hardcode `~/.config` while bootstrap derives from CONFIG_DEST.
- `bin/dotfiles:150-152` — `clean` silently ignores unknown args (typo'd `--al` does a real clean).
- `install/lib.sh:165` — `is_ignored` requires `.git` to be a directory; breaks in worktrees (would link `.serena/`, `.claude/` into ~/.config).
- `install/manifest.sh:105-119` — unknown `kind` tokens silently treated as `tree`.
- `manifest.conf:36` — lldb config links to a path lldb never reads on Ubuntu.
- `config/macos/defaults.zsh` — pre-Big Sur battery keys (no-op on 11+), SoftwareUpdate keys duplicated with harden.zsh, untyped `AppleShowAllFiles YES` and `NSWindowResizeTime .001`, misplaced comment.
- `config/htop/htoprc` — htop rewrites this file on any interactive change, dirtying the repo through the symlink.
- `config/homebrew/brew.env:6` — `HOMEBREW_NO_INSTALL_FROM_API=` empty assignment is a no-op.
- `config/git/gitconfig.local:33` — includeIf points at `~/dev/kth/.gitconfig`, which doesn't exist.

## Verified clean
- All 19 manifest src paths exist; packages.conf parses cleanly; --dry-run is genuinely mutation-free; shellcheck clean at warning level.
- tmux.conf fully valid, no deprecated options; karabiner JSON valid; clang-format/ripgrep/python/bat configs check out.
- All 100 nvim Lua files pass `luac -p`; no missing-module requires in enabled code paths.
- zsh startup hygiene already good: cached brew shellenv, cached op completion, mtime-checked compinit, zsh-defer.
