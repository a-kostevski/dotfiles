# Declarative source manifest — design

- Date: 2026-07-14
- Branch: `declarative-manifest`
- Addresses: `docs/REVIEW-2026-07-14.md` Phase 1.1, plus DEST-01, PROFILE-04,
  PROFILE-03, SCAFFOLD-01
- Status: approved for planning

## Problem

Four (really five) lifecycle concerns each re-derive the source→destination
file set their own way, and the knowledge of which components exist, which
profile and platform they belong to, and which four files map to `$HOME`
instead of `$XDG_CONFIG_HOME` is scattered across `install/profiles.sh`,
`install/symlinks.sh`, `bootstrap.sh`, and `bin/dotfiles`.

Current derivations:

1. **link** — `bootstrap.sh:link_configs` → `get_config_list` (profile
   expansion) → per-component `get_config_symlinks` (`find` + special-case
   zshenv / lldbinit / clang-format / curl).
2. **status** — `bin/dotfiles:cmd_status` re-runs the profile expansion and
   `get_config_symlinks`, *and* re-inlines the clang-format / curl path
   special cases, plus a separate `bin/` scan.
3. **clean** — `clean_broken_symlinks` reads the installed manifest's owned
   entries (this one is already fine — it reads recorded facts, not a
   re-derivation of the mapping).
4. **uninstall** — `cmd_uninstall` uses a filesystem ownership scan
   (`find_owned_symlinks`) plus a hardcoded `~/.zshenv` / `~/.lldbinit` list.
5. **`--synced`** — `bootstrap.sh` `SYNC_SYNCED` path calls
   `get_synced_configs` / `has_synced_binaries`, a filesystem-based
   re-derivation of the config set. No caller reaches it since PROFILE-01/02
   (hooks, watch, and the CLI all route through the stored profile).

## Goal

One tracked, declarative source of truth. `link`, `status`, and (scoped)
`uninstall` derive their file set from it; `clean` continues to operate on the
installed manifest, which becomes simply the projection of the source manifest
onto the current machine. Remove the dead profile/interactive/synced surface
and the partially-supported destination flags.

## Decisions (approved)

- **Manifest format:** a constrained TOML subset in a tracked data file, read
  by a single no-dependency awk reader. No `jq`/`yq`.
- **DEST-01:** remove `--config-dest` / `--bin-dest`. The manifest resolves
  `$XDG_CONFIG_HOME` / `$HOME` / `$HOME/.local/bin`. No evidence of
  alternate-destination use; the isolated tests drive layout by overriding
  `HOME`/`XDG_CONFIG_HOME`, not these flags. Half-supported flags *are* the
  DEST-01 bug; removing them closes it cleanly. The centralized manifest makes
  adding real alternate-root support cheap later if ever wanted.
- **PROFILE-04:** delete the interactive subsystem (`select_profile`,
  `select_custom_components`, `select_profile_with_current`,
  `detect_current_profile`, `CUSTOM_CONFIGS`) and reject `custom`. Valid
  profiles become `minimal | standard | full | all`. `custom` was actively
  harmful — it validated but silently degraded to minimal non-interactively.
- **`--synced` mode:** remove it and `get_synced_configs` /
  `has_synced_binaries`. Dead, and the last competing derivation.
- **`config/op`:** assign to the `full` profile (previously linked only via
  `all`).

## The manifest — `install/manifest.toml`

Data only, array-of-tables. One `[[entry]]` per mapping:

```toml
[[entry]]
name      = "nvim"
kind      = "tree"                 # tree | file
src       = "config/nvim"          # repo-relative
dest      = "{XDG_CONFIG}/nvim"    # placeholder-resolved
profiles  = ["standard", "full"]   # subset of minimal/standard/full
platforms = ["all"]                # all | subset of macos/ubuntu
```

Grammar (the only shapes the reader accepts):

- `[[entry]]` starts a new entry.
- `key = "value"` — a scalar string.
- `key = ["a", "b"]` — a string array (single-line).
- `#` line comments and blank lines ignored.

### Placeholders

Resolved by the reader against the environment:

- `{XDG_CONFIG}` → `${XDG_CONFIG_HOME:-$HOME/.config}`
- `{HOME}` → `$HOME`
- `{BIN}` → `$HOME/.local/bin`

### Entry kinds

- **`tree`** — link every non-ignored file under `src` to `dest/<relpath>`,
  applying the existing `is_ignored` filter, **except** any file that is the
  `src` of a `file` entry (shadowing). Reproduces the current "skip zshenv in
  the tree walk" behavior declaratively.
- **`file`** — link the single `src` file to the exact `dest`. It shadows
  itself out of any overlapping tree.

### Profile and platform semantics

- `profiles` — subset of `["minimal", "standard", "full"]`. A component is
  selected when the active profile is in its list.
- The `all` profile selects **every** entry (still platform-gated) regardless
  of `profiles`. An entry with `profiles = []` is reachable **only** via `all`.
  (No entry uses `[]` after the `op` decision; the semantic is retained.)
- `platforms` — `["all"]`, or a subset of `["macos", "ubuntu"]`. An entry is
  selected only when `OS_TYPE` matches.

### Entry set

Reproduces today's `PROFILE_CONFIGS` + `PROFILE_OS_SPECIFIC` + the four home
files, now in one place.

| name | kind | src → dest | profiles | platforms |
|---|---|---|---|---|
| git | tree | config/git → {XDG_CONFIG}/git | min,std,full | all |
| zsh | tree | config/zsh → {XDG_CONFIG}/zsh | min,std,full | all |
| tmux | tree | config/tmux → {XDG_CONFIG}/tmux | min,std,full | all |
| zsh-env | file | config/zsh/zshenv → {HOME}/.zshenv | min,std,full | all |
| nvim | tree | config/nvim → {XDG_CONFIG}/nvim | std,full | all |
| bat | tree | config/bat → {XDG_CONFIG}/bat | std,full | all |
| python | tree | config/python → {XDG_CONFIG}/python | std,full | all |
| ripgrep | tree | config/ripgrep → {XDG_CONFIG}/ripgrep | std,full | all |
| clang-format | file | config/clang-format → {HOME}/.clang-format | full | all |
| curl | file | config/.curlrc → {HOME}/.curlrc | full | all |
| lldb | tree | config/lldb → {XDG_CONFIG}/lldb | full | all |
| lldb-init | file | config/lldb/.lldbinit → {HOME}/.lldbinit | full | macos |
| op | tree | config/op → {XDG_CONFIG}/op | full | all |
| homebrew | tree | config/homebrew → {XDG_CONFIG}/homebrew | full | macos |
| karabiner | tree | config/karabiner → {XDG_CONFIG}/karabiner | full | macos |
| kitty | tree | config/kitty → {XDG_CONFIG}/kitty | full | macos |
| bin | tree | bin → {BIN} | min,std,full | all |

Notes:

- `lldb` (tree) links `lldbinit.py` and other files to `{XDG_CONFIG}/lldb` on
  all platforms in the full profile — `.lldbinit` contains
  `command script import ~/.config/lldb/lldbinit.py`, so that path is needed.
  `lldb-init` (file, macOS) links `.lldbinit` to `~/.lldbinit`, which is what
  LLDB actually reads. Shadowing removes the current redundant
  `{XDG_CONFIG}/lldb/.lldbinit` link; nothing references it.
- `bin` is always linked (all profiles), matching current behavior where every
  `bin/` script links regardless of profile. Per-script platform gating is out
  of scope.
- Provisioning directories (`config/macos`) are not linkable components and are
  absent from the manifest, as today.

## Reader module — `install/manifest.sh`

A single awk isolates all TOML parsing; no other code touches the format.
Public API — the single source every command calls:

- `manifest_links <profile> <os>` → `src_file|dest_file` pairs. Tree entries
  expand with `is_ignored` + shadowing; file entries emit one pair. **The one
  derivation.**
- `manifest_components <profile> <os>` → selected component names (status
  section headers).
- `manifest_component_links <name> <os>` → pairs for a single component
  (scoped sync / uninstall).
- `manifest_component_exists <name>` → name is in the manifest and its `src`
  exists.
- `manifest_home_dests <os>` → dests of `file`-kind entries that fall outside
  `{XDG_CONFIG}` and `{BIN}` (used by full uninstall for home-file targets).

`validate_profile` (now `minimal | standard | full | all`) and
`get_profile_description` move here.

### Deletions

- `install/profiles.sh` — deleted entirely. `PROFILE_CONFIGS`,
  `PROFILE_OS_SPECIFIC`, `get_config_list`, `get_all_existing_configs`,
  `config_component_exists`, and the whole interactive subsystem go with it.
- `install/symlinks.sh` — remove `get_config_symlinks`, `get_synced_configs`,
  `has_synced_binaries`, and the already-dead `check_symlink_health`. Keep all
  create / check / clean / uninstall / installed-manifest machinery
  (`create_symlink`, `check_symlink`, `clean_broken_symlinks`,
  `is_owned_symlink`, `find_owned_symlinks`, backup/restore, `update_manifest`,
  `remove_manifest_entries`).
- `bootstrap.sh` — remove `--synced` / `SYNC_SYNCED`, `--config-dest`,
  `--bin-dest`.

Sourcing in `bootstrap.sh` and `bin/dotfiles` switches from `profiles.sh` to
`manifest.sh`.

## Command rewiring

Each command derives its file set from `manifest_links`.

- **link** (`bootstrap.sh:link_configs`): iterate
  `manifest_links "$PROFILE" "$OS_TYPE"` and `create_symlink` each pair.
  `link_binaries` folds in — `bin` is a manifest entry. `--config <name>` uses
  `manifest_component_links`. `create_symlink` still writes the installed
  manifest via `update_manifest`; lineage is source manifest → links →
  installed manifest.
- **status** (`bin/dotfiles:cmd_status`): section headers from
  `manifest_components`, pairs from `manifest_links`, `check_symlink` each.
  The inline clang-format / curl special cases and the separate `bin/` scan
  are removed. Existing profile-aware exit codes (STATUS-01) are preserved.
- **clean** (`clean_broken_symlinks`): unchanged. Installed-manifest ownership
  (CLEAN-01) remains correct; `--all` global cleanup preserved.
- **uninstall** (`cmd_uninstall`): full uninstall keeps the filesystem
  ownership scan (robust; catches orphans from profile downgrades). The
  hardcoded `~/.zshenv` / `~/.lldbinit` targets are replaced by
  `manifest_home_dests`. Scoped uninstall uses `manifest_component_links`.
  Ownership checks, backup restoration, and manifest pruning (S-02) are
  preserved.

## Installed manifest, migration, hooks, scaffold

- **Installed manifest** (`~/.config/.dotfiles-manifest`, `timestamp|src|dest`)
  is unchanged and still written by `create_symlink`.
- **Migration**: none. Reconcile is idempotent; existing installed manifests
  stay valid. A legacy stored `custom` profile now fails `validate_profile`
  with guidance (`run: dotfiles profile standard`).
- **PROFILE-03**: the `post-checkout` / `post-merge` hooks widen change
  detection from `config/` only to a defined lifecycle-input set: `config/`,
  `install/manifest.toml`, `install/manifest.sh`, `install/symlinks.sh`,
  `bin/`, `bootstrap.sh`.
- **SCAFFOLD-01**: delete empty `config/defaults`, `config/security`,
  `config/ubuntu` (verify empty first).

## Testing

- New `tests/test-manifest.sh` against a fixture manifest: parser (scalars,
  arrays, comments), profile + platform selection, `all`, empty-`profiles`,
  tree expansion, zshenv shadowing, `is_ignored` skip, file entries,
  `manifest_home_dests`, `manifest_component_exists`.
- Update `tests/test-bootstrap.sh` (only file referencing removed symbols) to
  manifest-driven equivalents; drop `custom` and `--config-dest`/`--bin-dest`
  assertions.
- Add TEST-03 lifecycle coverage: `profile standard` then default `sync` adds
  standard configs; profile-aware status exit codes; ownership-scoped clean;
  uninstall home-file derivation via the manifest.
- `make test` stays green on macOS and Ubuntu.

## Documentation

- README / CLAUDE.md: remove `--config-dest` / `--bin-dest` and the `custom`
  profile; document the manifest as the source of truth and how to add a
  component; note `op` in full.
- Mark the addressed `docs/REVIEW-2026-07-14.md` Phase 1 entries Resolved with
  the fixing commit, matching the existing `Resolved: <date> by <commit>`
  style: Phase 1.1, DEST-01, PROFILE-04, PROFILE-03, SCAFFOLD-01.

## Out of scope

- Package profiles / installer changes (PACKAGE-01, Phase 2+).
- Per-`bin`-script platform gating.
- Interactive profile selection (deliberately removed, not rebuilt).
- Real alternate-destination support (flags removed; can be re-added on the
  manifest later).
- CLI-01 (unknown-command exit code) — separate finding.

## Definition of done

- `install/manifest.toml` exists and is the single declaration; `link`,
  `status`, and scoped `uninstall` derive their file set from it via
  `manifest.sh`; `clean` operates on the installed manifest projected from it.
- `--config-dest` / `--bin-dest` removed; `custom` rejected; interactive and
  `--synced` surface deleted; empty scaffold trees removed.
- Hooks trigger sync on the defined lifecycle inputs, including the manifest.
- `make test` green with new manifest and lifecycle coverage.
- README / CLAUDE.md updated; review Phase 1 entries marked Resolved.
