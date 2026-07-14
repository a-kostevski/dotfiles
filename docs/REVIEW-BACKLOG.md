# Review backlog

> **Historical document:** this checklist records the 2026-07-10 and
> 2026-07-11 reviews, but several unchecked entries have since been fixed. Use
> the consolidated [2026-07-14 review](REVIEW-2026-07-14.md) for current
> findings, validation evidence, and remediation order. Keep this file for
> provenance rather than treating every unchecked item as active work.

Remaining findings from the 2026-07-10 full-repo review. Everything here was
deliberately deferred — the bugs found in that review were fixed in the
commit series `192d99e..3ed7357`. Items are grouped by area and roughly
ordered by value within each group.

Items tagged `(2026-07-11)` come from the deep multi-agent audit on that date;
the correctness fixes from that audit were committed on the
`feature/dotfiles-uninstall` branch, and the entries below are what it deferred.

## Install / shell tooling

- [x] **`dotfiles uninstall` command.** The manifest (`~/.config/.dotfiles-manifest`)
  is written on every link (`install/symlinks.sh`) but never consumed;
  it grows unbounded with no dedup, and `read_manifest` is dead code. An
  uninstall/restore-from-backup command is the natural consumer.
  (done ecf6e6e — uninstall command + manifest dedup and entry removal landed
  on `feature/dotfiles-uninstall`)
- [ ] **Ubuntu Neovim too old (HIGH)** (2026-07-11): `install-ubuntu.sh:30`
  installs apt `neovim` (0.6–0.9) but this repo's config uses 0.11-only APIs,
  so standard/full Ubuntu installs error on startup. Install from the PPA or a
  0.11+ AppImage and add a version-floor check.
- [ ] **`config/clang-format` is a file, not a directory.** The full profile
  lists it but `link_configs` only handles directories, so it is silently
  skipped — and `~/.config/clang-format/` wouldn't be read by clang-format
  anyway. Decide: move into a directory with special-case linking to
  `~/.clang-format`, or drop it from the profile.
- [ ] **Dead interactive profile subsystem + `custom` profile.** The `custom`
  profile is unreachable non-interactively and missing from `--help`. More
  broadly (2026-07-11), ~180–250 lines in `install/profiles.sh`
  (`select_profile`, `select_custom_components`, `select_profile_with_current`,
  `detect_current_profile`, `CUSTOM_CONFIGS`) are never called — wire the
  interactive selector up or delete it and drop `custom` from `validate_profile`.
- [ ] **`-c`/`-b` (`CONFIG_DEST`/`BIN_DEST`) only half-honored** (2026-07-11):
  only `link_configs`/`link_binaries` respect them; the manifest, `clean`,
  `validate`, `uninstall`, and dir-creation all hardcode `$HOME`. Thread the
  destinations through everywhere or remove `-c`/`-b` from the usage.
- [ ] **Broken-symlink logic reimplemented 4x** (2026-07-11):
  `clean_broken_symlinks` vs two Makefile `find` pipelines vs the inline
  `status` scan. The Makefile copies use bare `rm`, miss `$HOME` links, and
  ignore the manifest. Unify behind `bin/dotfiles`; delete dead
  `check_symlink_health` (no callers).
- [ ] **Makefile gaps** (2026-07-11): no generic `ARGS` passthrough (can't reach
  `--force`/`--skip-install`/`-c`/`-b`), no `uninstall` target, and `update`
  ignores `DRY_RUN`.
- [ ] **Ubuntu network failure aborts whole setup** (2026-07-11):
  `install-ubuntu.sh` runs under `set -euo pipefail`, so a transient
  `wget`/`apt` hiccup (eza repo, thefuck, `apt-get update`) aborts everything
  after it. Wrap optional steps and add retry.
- [ ] **Empty scaffolding dirs**: `config/security/`, `config/defaults/`,
  `config/ubuntu/apt/` — delete or populate.
- [ ] **Smaller robustness nits**: `bin/nshift:94` uses `bc` without checking
  it exists (and computes `seconds` before validating, which breaks on
  fractional hours); `config/homebrew/brew.env` sets
  `HOMEBREW_NO_INSTALL_FROM_API=` empty and is never sourced (dead config).
- [ ] **Harden smaller bin scripts** (2026-07-11): `countdown` uses macOS-only
  `afplay` (needs a portable sound + numeric-arg validation + drop the
  unreachable ZLE branch); `lnclean` should add `set -eu`; `mkx` needs a
  fallback editor when `$EDITOR` is empty.
- [ ] **`bin/osx-clock-toggle`**: fragile `grep -q '1'` match (matches "10"),
  writes `-int` where `cantsleep` writes `-bool` for the same key. Consider
  deleting it in favor of `cantsleep`.

## Zsh

- [ ] **Tool adoption decisions** (all fit the existing lazy-load/cache
  patterns): zoxide (would replace `functions/cd`, which `auto_cd` bypasses
  anyway), direnv (no per-project env hook exists), atuin (matches the heavy
  history config).
- [ ] **`_poetry` completion leaks the author's home path** (2026-07-11):
  `config/zsh/completions/_poetry:197` embeds
  `/Users/antonkostevski/.local/pipx/venvs/poetry/bin/poetry` — broken and an
  identity leak on any other machine. Regenerate the completion or strip the path.
- [ ] **Startup perf**: `_plug_compile` (zrecompile) in
  `rc.d/70-zsh-unplugged.zsh` is defined but never called; rc.d/profile.d
  files are never `zcompile`d; `GPG_TTY=$(tty)` forks (use zsh's `$TTY`);
  `fzf --zsh` is executed twice in `rc.d/71-plugins.zsh:16-17`.
- [ ] **`compinit` without `-i`** (`rc.d/30-completions.zsh:39`): first shell
  of the day can prompt about insecure directories if brew site-functions is
  group-writable.
- [ ] **compinit cache invalidated per calendar-day** (2026-07-11):
  `rc.d/30-completions.zsh` rebuilds `zcompdump` on a date change rather than
  comparing `zcompdump` mtime against the newest `fpath` dir, so a completion
  added today isn't registered until tomorrow.
- [ ] **`reload` alias execs `$SHELL`, not zsh**
  (`rc.d/60-aliases.zsh:154`, 2026-07-11): `exec $SHELL` loads the login-shell
  binary, which may not be zsh; use `exec zsh` (or `$commands[zsh]`).
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

- [ ] **`docker.lua` is copy-paste corrupted** (2026-07-11):
  `config/nvim/lua/kostevski/plugins/lang/docker.lua` registers with
  `name`/`filetypes` "Caddyfile", `lsp_server = "gopls"`, and Go formatters
  while carrying Docker `root_markers`/hadolint. Dormant (docker disabled) but
  broken — fix the name/filetype/server/formatters.
- [ ] **Native LSP loader ignores lspconfig-only hooks** (2026-07-11):
  `config/nvim/lsp/{jsonls,yamlls,pyright}.lua` rely on `on_new_config` /
  `flags.debounce`, which `vim.lsp.config`/`vim.lsp.enable` never invoke, so
  SchemaStore schemas won't load once those servers are enabled. Latent.
- [ ] **gitsigns `undo_stage_hunk`** (`plugins/editor/gitsigns.lua:87`):
  still present in the current checkout but deprecated upstream and the
  plugin is unpinned — migrate `<leader>ghu` to the stage-toggle API or pin
  gitsigns before it breaks.
- [ ] **Version claim**: `utils/lang.lua:12` advertises "Neovim 0.10 and
  0.11+" but the config uses 0.11-only APIs (`vim.validate` positional form,
  `vim.lsp.config`, `vim.diagnostic.jump`). Drop the 0.10 claim.
- [ ] **Consolidate icon providers** (2026-07-11): call
  `require('mini.icons').mock_nvim_web_devicons()` and drop the explicit
  `nvim-web-devicons` deps in telescope/lualine/bufferline/markdown/neo-tree.
  Load-order sensitive — verify in a real nvim.
- [ ] **Doubled lazy import graph** (2026-07-11): `config/lazy.lua` imports the
  category subtrees (coding/ui/editor/lsp/ai) both directly and via the parent
  import — collapse to one path.
- [ ] **which-key + telescope key nits** (2026-07-11): relabel the `<leader>n`
  group Notes→Notifications (`which-key.lua`); the `<leader>fu` Telescope
  colorscheme mapping drops its `desc`/`enable_preview` (`telescope.lua`).
- [ ] **Right-size always-loaded tools** (2026-07-11): `hardtime.nvim` + `nui`
  load every session while disabled by default (`tools/hardtime.lua`) — load
  them on `cmd`/`keys` instead.
- [ ] **nvim library coupling / dead helpers** (2026-07-11): cache a sentinel
  on failed `pcall(require)` in the `utils/init.lua` and `lsp/init.lua`
  `__index` loaders (avoid a notify per access); replace `Utils.is_list` with
  `vim.islist`; trim the `create_simple` docstring in `lang.lua`.
- [ ] **Dead surface**: `Keys.map` and the `DebugLspKeys` command in
  `utils/keys.lua` have no callers; `mini-starter.lua` has dead
  `format_section`/`create_header` locals; `format.lua:99-101` doc `@param`
  order swapped; stale comment in `utils/toggle.lua:63` referencing the
  removed errors module.

## Packages / parity

New from the 2026-07-11 audit.

- [ ] **macOS `Brewfile-min` lacks eza/bat/htop** that the zsh aliases expect
  (Ubuntu already installs all three) — add them for parity.
- [ ] **Ubuntu lacks nodejs + wl-clipboard**: macOS installs node and many
  Mason/LSP tools assume it; `wl-clipboard` gives nvim a Wayland clipboard
  provider. Add both to `install-ubuntu.sh`.
- [ ] **Dead Homebrew/Brewfile config**: set `HOMEBREW_NO_AUTO_UPDATE`; drop the
  duplicate `wget`/`clang-format`/`python` entries in `Brewfile-all`. (The
  unused `config/homebrew/brew.env` is already noted under Install / shell
  tooling.)

## Testing / CI

New from the 2026-07-11 audit.

- [ ] **Headless nvim + `zsh -ic` load smoke test** in CI: `luac -p` / `zsh -n`
  are parse-only, so a broken `require` chain or an `rc.d` runtime error passes
  today. Add a real load test for both.
- [ ] **luacheck + `stylua --check` CI gate** — blocked on a whole-tree
  reformat: `config/nvim/stylua.toml` declares 2-space but ~57/101 nvim lua
  files are 3-space. Reformat, then add the gate.
- [ ] **Unit tests for platform-branching core fns**: `detect_os`,
  `get_brewfile_for_profile`, `get_default_home`, `get_brew_prefix`
  (`install/lib.sh`, `homebrew.sh`) have zero tests. Also delete dead
  `resolve_path` (`install/lib.sh:198`, no callers).
- [ ] **Extract a shared test harness** to `tests/lib.sh`: the PASS/FAIL and
  assert helpers are byte-duplicated across both test files.
- [ ] **CI concurrency cancellation + shellcheck `.githooks`**: add a
  `concurrency` block; extend shellcheck coverage to `.githooks/*`; quote
  `'HEAD@{1}'` in `post-merge:8`.
- [ ] **Git hooks parity/logging/docs**: add `set -uo pipefail` to the hooks,
  log the backgrounded `post-checkout` sync, and document `.githooks/setup.sh`.

## Misc configs

- [ ] **macOS TouchID `sudo_local` clobbers PAM** (2026-07-11):
  `config/macos/defaults.zsh:270` unconditionally `cp`s the template over
  `/etc/pam.d/sudo_local` every run (destroys `pam_reattach` etc.) and has no
  macOS<14 guard. Make it idempotent and version-gated.
- [ ] **macOS Finder PlistBuddy `Set` fails on a fresh install** (2026-07-11):
  `config/macos/defaults.zsh:131` — the nested `IconViewSettings` keys don't
  exist on a clean machine, so `Set` errors. Use `Set … || Add …`.
- [ ] **bat theme decision**: config sets `--theme="Nord"` while a vendored
  `tokyonight-moon` theme ships unregistered (needs `bat cache --build`,
  which nothing runs). Either switch and add the cache build to
  bootstrap/sync, or delete the vendored theme.
- [ ] **Stale macOS defaults** (`config/macos/defaults.zsh`): the
  NotificationCenter `launchctl unload` (SIP-protected since Big Sur), the
  `com.apple.rcd` media-key hijack (rcd removed), and `LSQuarantine` are all
  dead — remove them.
- [ ] **Delete dead/duplicate terminal surface** (2026-07-11): the unused kitty
  kittens (`neighboring_window`/`relative_resize`/`split_window.py` — `kitty.conf`
  uses built-ins) and the no-op `src -c`/`--cmd` branch
  (`config/zsh/functions/src:52`).
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
  confirm that's intentional (a fresh clone gets neither, yet `docs/superpowers/`
  is tracked, so a clone loses the substantial project `CLAUDE.md`). Also
  (2026-07-11) add `.superpowers/` to `.gitignore` explicitly, and fix the
  Makefile reference to a nonexistent `scripts/**/*` glob.
