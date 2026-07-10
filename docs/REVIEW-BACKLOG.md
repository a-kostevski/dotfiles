# Review backlog

Remaining findings from the 2026-07-10 full-repo review. Everything here was
deliberately deferred — the bugs found in that review were fixed in the
commit series `192d99e..3ed7357`. Items are grouped by area and roughly
ordered by value within each group.

## Install / shell tooling

- [ ] **`dotfiles uninstall` command.** The manifest (`~/.config/.dotfiles-manifest`)
  is written on every link (`install/symlinks.sh`) but never consumed;
  it grows unbounded with no dedup, and `read_manifest` is dead code. An
  uninstall/restore-from-backup command is the natural consumer.
- [ ] **`config/clang-format` is a file, not a directory.** The full profile
  lists it but `link_configs` only handles directories, so it is silently
  skipped — and `~/.config/clang-format/` wouldn't be read by clang-format
  anyway. Decide: move into a directory with special-case linking to
  `~/.clang-format`, or drop it from the profile.
- [ ] **`custom` profile unreachable non-interactively** and missing from
  `--help`; either wire it up or drop the CLI-side validation for it.
- [ ] **Empty scaffolding dirs**: `config/security/`, `config/defaults/`,
  `config/ubuntu/apt/` — delete or populate.
- [ ] **Smaller robustness nits**: `bin/nshift:94` uses `bc` without checking
  it exists (and computes `seconds` before validating, which breaks on
  fractional hours); `config/homebrew/brew.env` sets
  `HOMEBREW_NO_INSTALL_FROM_API=` empty and is never sourced (dead config).
- [ ] **`bin/osx-clock-toggle`**: fragile `grep -q '1'` match (matches "10"),
  writes `-int` where `cantsleep` writes `-bool` for the same key. Consider
  deleting it in favor of `cantsleep`.

## Zsh

- [ ] **Tool adoption decisions** (all fit the existing lazy-load/cache
  patterns): zoxide (would replace `functions/cd`, which `auto_cd` bypasses
  anyway), direnv (no per-project env hook exists), atuin (matches the heavy
  history config).
- [ ] **Startup perf**: `_plug_compile` (zrecompile) in
  `rc.d/70-zsh-unplugged.zsh` is defined but never called; rc.d/profile.d
  files are never `zcompile`d; `GPG_TTY=$(tty)` forks (use zsh's `$TTY`);
  `fzf --zsh` is executed twice in `rc.d/71-plugins.zsh:16-17`.
- [ ] **`compinit` without `-i`** (`rc.d/30-completions.zsh:39`): first shell
  of the day can prompt about insecure directories if brew site-functions is
  group-writable.
- [ ] **PATH/FPATH dedup uses regex `=~`** with unescaped metacharacters in
  `profile.d/10-path.zsh` and `00-fpath.zsh`; it is also redundant with
  `typeset -U path fpath`. Use `(( ${path[(Ie)$dir]} ))` or drop the check.
- [ ] **`title()` in `rc.d/90-window.zsh`**: xterm branch emits raw `$2`
  instead of the escaped/truncated `$a`; screen branch uses a `$3` no caller
  passes.
- [ ] **Correctness nits**: unquoted operands in `.zprofile:8,17` and around
  `XDG_RUNTIME_DIR`-adjacent tests; `export` on arrays
  (`ZSH_HIGHLIGHT_HIGHLIGHTERS`, `ZSH_AUTOSUGGEST_STRATEGY`) is a no-op;
  top-level `local` leaks globals (`.zprofile`, `30-completions.zsh`,
  `71-plugins.zsh`, `.zshrc`); `40-history.zsh` needlessly exports
  HISTSIZE/SAVEHIST/HISTFILE; `uvx --generate-shell-completion` flag
  unverified; lazy-loaded uv/uvx completions have a chicken-and-egg problem
  (`uv <TAB>` empty until first run); duplicate patterns in the completion
  `file-ignore` list; `HISTORY_IGNORE` only covers trivial commands.

## Neovim

- [ ] **gitsigns `undo_stage_hunk`** (`plugins/editor/gitsigns.lua:87`):
  still present in the current checkout but deprecated upstream and the
  plugin is unpinned — migrate `<leader>ghu` to the stage-toggle API or pin
  gitsigns before it breaks.
- [ ] **Version claim**: `utils/lang.lua:12` advertises "Neovim 0.10 and
  0.11+" but the config uses 0.11-only APIs (`vim.validate` positional form,
  `vim.lsp.config`, `vim.diagnostic.jump`). Drop the 0.10 claim.
- [ ] **Dead surface**: `Keys.map` and the `DebugLspKeys` command in
  `utils/keys.lua` have no callers; `mini-starter.lua` has dead
  `format_section`/`create_header` locals; `format.lua:99-101` doc `@param`
  order swapped; stale comment in `utils/toggle.lua:63` referencing the
  removed errors module.

## Misc configs

- [ ] **bat theme decision**: config sets `--theme="Nord"` while a vendored
  `tokyonight-moon` theme ships unregistered (needs `bat cache --build`,
  which nothing runs). Either switch and add the cache build to
  bootstrap/sync, or delete the vendored theme.
- [ ] **Stale macOS defaults** (`config/macos/defaults.zsh`): the
  NotificationCenter `launchctl unload` (SIP-protected since Big Sur), the
  `com.apple.rcd` media-key hijack (rcd removed), and `LSQuarantine` are all
  dead — remove them.
- [ ] **Vendored `config/lldb/lldbinit.py`** (5.5k lines, fG!'s lldbinit
  v3.1): replace the hand-copied blob with a pinned download or submodule.
- [ ] **Brewfile inconsistency**: `Brewfile-min` installs the kitty cask but
  `Brewfile-all` (used by the full profile, which links the kitty config)
  does not — reconcile.
- [ ] **Git credential helper**: no `credential.helper = osxkeychain` on
  macOS (or `gh auth setup-git`) for HTTPS remotes.
- [ ] **SSH config management**: no `config/ssh/` managing
  `IdentityAgent`/host aliases despite the 1Password SSH-agent setup.
- [ ] **Tracking decisions**: `CLAUDE.md` and `docs/plans/` are git-ignored —
  confirm that's intentional (a fresh clone gets neither).
