# Separate package installation from link profiles — design

- Date: 2026-07-14
- Branch: `package-profiles`
- Addresses: `docs/REVIEW-2026-07-14.md` Phase 2 — PACKAGE-01, HOMEBREW-01,
  UBUNTU-02, DOC-02
- Builds on: `docs/superpowers/specs/2026-07-14-declarative-manifest-design.md`
  (the declarative *link* manifest, already shipped on `main`)
- Status: approved for planning

## Problem

`profile` (`minimal | standard | full | all`) conflates two unrelated concerns:
which configs get **linked** and which packages get **installed**. Phase 1 made
the profile authoritative for linking via `install/manifest.toml`. Package
installation, however, remains ad-hoc and inconsistent:

1. **PACKAGE-01** — On macOS, `get_brewfile_for_profile` maps both `minimal`
   and `standard` to `Brewfile-min`, which installs Neovim, Node, and Python
   despite `minimal` being described as git/zsh/tmux. On Ubuntu,
   `install_ubuntu_packages` ignores the profile entirely and installs one
   hardcoded list for every profile.
2. **HOMEBREW-01** — `configure_homebrew` writes `~/.config/homebrew/config`,
   which Homebrew does not read as an environment file. The tracked, correct
   `brew.env` is linked only by the `full` *link* profile, and only *after* the
   first `brew bundle`, so its settings (e.g. `HOMEBREW_NO_AUTO_UPDATE`) do not
   apply during the install that matters. `minimal`/`standard` never link it.
3. **UBUNTU-02** — `install/install-ubuntu.sh` runs `set -euo pipefail`. A
   transient failure adding the eza repo, refreshing apt, or installing
   `thefuck` aborts the whole run after earlier packages already mutated the
   system. The eza repo URL is also HTTP.
4. **DOC-02** — README profile descriptions do not match package behavior.

Package installation is inherently imperative (distinct brew/apt package names,
third-party repos, `sudo`, network, distro differences), so the fix is not to
force everything into data, but to make the **selection** declarative, pure,
and testable while keeping the genuinely imperative tail as explicit,
retryable code.

## Decisions (approved)

- **`profile` means link-set only.** Package installation is a separate,
  explicit, tier-aware operation.
- **Declarative package manifest** `install/packages.toml`, paralleling
  `install/manifest.toml`, read by a no-dependency awk reader
  `install/packages.sh` (mirrors `install/manifest.sh`). It covers only direct
  package-manager installs.
- **Imperative tail stays as code.** Third-party repos and `curl | sh`
  installers (Ubuntu `eza-repo`, `uv`, `thefuck`, `nvim-archive`) remain
  explicit, tier-gated installer functions. macOS currently has none — every
  macOS package is a brew formula or cask.
- **Tier selection defaults to the link profile, overridable.** New
  `--packages <minimal|standard|full>` flag. `--install-packages` installs the
  tier matching the active profile by default (`all` profile → `full`
  packages); `--packages` overrides. The tiers are an independent knob that
  merely *default-aligns* with the profile; docs state this explicitly.
- **Package installer owns `brew.env`.** It links
  `config/homebrew/brew.env → ~/.config/homebrew/brew.env` (via the existing
  `create_symlink`, so it is backed up and tracked) **before** invoking brew,
  at every tier. The undocumented `~/.config/homebrew/config` write is deleted,
  and the `homebrew` entry is removed from the *link* manifest (it is now a
  package-install concern, not user config).
- **Ubuntu required vs optional is category-based** (no new manifest field).
  The manifest-selected apt set is required and installed atomically; the
  imperative network extras are optional, retried with backoff, HTTPS-preferred,
  and their failures summarized at the end without aborting.
- **`Brewfile-min` / `Brewfile-all` are removed.** The macOS executor generates
  a Brewfile from the selected names and runs `brew bundle`.

## The package manifest — `install/packages.toml`

Data only, array-of-tables, same grammar the link manifest reader already
accepts (`[[table]]`, `key = "value"`, `key = ["a", "b"]`, `#` comments).

```toml
[[package]]
name  = "neovim"
tiers = ["standard", "full"]   # subset of minimal/standard/full
brew  = "neovim"               # macOS formula   ("" = skip on macOS)
cask  = ""                     # macOS cask      (GUI apps; "" = none)
apt   = ""                     # ubuntu apt pkg  ("" = skip / handled by an extra)
```

### Fields

- `name` — unique id (also the display/summary label).
- `tiers` — subset of `["minimal", "standard", "full"]`. A package is selected
  when the requested tier is in its list. (`full` ⊇ `standard` ⊇ `minimal` is
  expressed by listing every tier a package belongs to; there is no implicit
  nesting in the reader — the manifest lists tiers explicitly per package.)
- `brew` — macOS Homebrew formula name, or `""`.
- `cask` — macOS Homebrew cask name, or `""`.
- `apt` — Ubuntu apt package name, or `""`.

### Platform gating is implicit

There is no `platforms` field. Selection is per-OS by which field is populated:

- **macOS** selects `brew` and `cask` names (non-empty) for the tier.
- **Ubuntu** selects `apt` names (non-empty) for the tier.

A GUI cask (`cask = "1password"`, `apt = ""`) is simply absent on Ubuntu. A
Linux-only apt package (`apt = "xclip"`, `brew = ""`) is absent on macOS.
Packages whose Ubuntu install is imperative (Neovim archive, eza repo) carry an
empty `apt` and are handled by an extra (below).

### Reader module — `install/packages.sh`

A single awk block isolates all TOML parsing; no other code touches the format.
Mirrors `install/manifest.sh`'s structure and helpers (`_manifest_csv_has`
equivalent). Public API:

- `packages_select <tier> <os> <field>` — emit the non-empty `<field>` values
  (`brew` | `cask` | `apt`) of packages whose `tiers` include `<tier>`, one per
  line. **The one pure selection function.**
- `validate_tier <tier>` — accept `minimal | standard | full`; reject anything
  else with guidance.
- `resolve_package_tier <profile> [override]` — map an override (if given) or a
  link profile to a package tier: `minimal→minimal`, `standard→standard`,
  `full→full`, `all→full`. Returns the tier; validates it.

These are pure (no network, no sudo, no filesystem mutation) and unit-tested
against a fixture manifest.

### Proposed tier contents

Starting point derived from today's `Brewfile-min`, `Brewfile-all`, and the
Ubuntu list, corrected so `minimal` no longer pulls Neovim/Node/Python.

**minimal** (essentials, matches the `minimal` *link* profile git/zsh/tmux):
git, git-lfs, curl, wget, zsh, tmux.

**standard** (minimal + common dev tools, matches `standard` link nvim/bat/python):
neovim, ripgrep, fd, fzf, jq, tree, bat, eza, htop, node, python, uv, and the
GNU userland macOS relies on (coreutils, findutils, gnu-sed, grep).

**full** (standard + everything from `Brewfile-all`): gh, git-delta, cmake,
clang-format, cppcheck, llvm; languages python@3.12, ruby, rust, go, openjdk,
perl; pyenv, pyenv-virtualenv, pnpm; network (nmap, netcat, nghttp2, aria2);
security (gnupg, lynis); media (ffmpeg, imagemagick, ghostscript); system libs
(openssl@3, pcre, readline, sqlite, xz, zlib, gettext, libssh2, libusb,
libxml2, libxslt, libzip); casks (1password, 1password-cli, alfred, appcleaner,
brave-browser, daisydisk, flux, font-hack-nerd-font, kitty, little-snitch,
the-unarchiver, transmission, vlc, wireshark, docker, postman, mullvadvpn,
tor-browser, knockknock, launchcontrol, taskexplorer).

Ubuntu apt names differ where required (`fd-find`, `bat` → symlinked to
`fd`/`bat`, `build-essential`, `software-properties-common`, `python3-pip`,
`unzip`, `xclip`); Neovim and eza are Ubuntu extras, not apt entries. Exact
per-package `apt`/`brew`/`cask` assignment is finalized in the plan.

## Tier selection wiring (`bootstrap.sh`)

- New option `--packages <minimal|standard|full>` sets `PACKAGE_TIER`.
- If `--install-packages` is given without `--packages`, `PACKAGE_TIER` is
  `resolve_package_tier "$PROFILE"` (profile default; `all→full`).
- `--packages` without `--install-packages` is a usage error (nothing to do).
- `PACKAGE_TIER` is validated and exported to the installers alongside the
  existing `INSTALL_PACKAGES` gate. The install summary reports the resolved
  package tier.

## macOS executor (`install/homebrew.sh`, `install/install-macos.sh`)

1. **Establish `brew.env` first.** Before any brew invocation,
   `create_symlink "$dot_root/config/homebrew/brew.env"
   "$HOME/.config/homebrew/brew.env"` so Homebrew reads it during the install.
   Delete `configure_homebrew` and its `~/.config/homebrew/config` write.
2. **Select names** via `packages_select "$PACKAGE_TIER" macos brew` and
   `... macos cask`.
3. **Generate a Brewfile** from the selected formulae/casks (temp file) and run
   `brew bundle --file=<generated>`. Remove `get_brewfile_for_profile`,
   `Brewfile-min`, `Brewfile-all`.
4. macOS has no imperative extras today.

The `homebrew` entry is removed from `install/manifest.toml` (link manifest).
`config/homebrew/` retains only `brew.env`.

## Ubuntu executor (`install/install-ubuntu.sh`)

1. **Required, atomic:** `apt-get update` then a single
   `apt-get install -y <packages_select "$PACKAGE_TIER" ubuntu apt>`. A failure
   here is a real failure (non-zero exit).
2. **Optional extras**, each wrapped so failure never aborts the run:
   `eza-repo` (+ `eza`), `uv`, `thefuck`, `nvim-archive`, and the
   `fd`/`bat` compatibility symlinks. Each is tier-gated (e.g. `nvim`,
   `eza`, `thefuck` are standard/full; minimal installs only the required base).
3. Extras run through `run_optional_step "<name>" <command...>`, which retries
   network operations with backoff, records failures into an array, and prints
   a single summary at the end (`"Optional steps that failed: thefuck, eza"`).
4. The eza repository URL becomes `https://deb.gierens.de` (was HTTP).

### New `lib.sh` helpers

- `retry <attempts> <delay> -- <command...>` — run a command, retrying up to
  `attempts` times with `delay` seconds between tries; returns the last exit
  status. No `sleep` in dry-run.
- `run_optional_step <name> <command...>` — invoke a step (wrapping network
  pieces in `retry`), and on failure append `<name>` to a module-level
  `OPTIONAL_FAILURES` array instead of exiting. A `report_optional_failures`
  call at the end of the installer prints the summary and returns success
  (optional failures do not fail the installer).

## Testing

New `tests/test-packages.sh` against a fixture `packages.toml`:

- Parser: scalars, arrays, comments, blank lines.
- `packages_select` tier filtering; per-field selection (`brew`/`cask`/`apt`);
  implicit platform gating (a cask absent on ubuntu, an apt-only pkg absent on
  macos); empty-field exclusion.
- `validate_tier` accept/reject; `resolve_package_tier` mapping incl. `all→full`
  and override precedence.

Executor planning tests (no network/sudo), following the stubbing pattern in
`tests/macos-defaults-regression.zsh` / `tests/test-macos-defaults.sh`:

- macOS: stub `brew`; assert the generated Brewfile contains exactly the
  tier-selected formulae/casks and that `brew.env` is linked before `brew
  bundle` runs.
- Ubuntu: stub `apt-get` and network commands; assert the required apt set for
  a tier; assert a **failing** optional step is retried, does **not** abort, and
  appears in the summary; assert HTTPS eza URL.
- `retry`: succeeds after N failures; gives up after `attempts`; no real sleep
  under `DRY_RUN`.

Isolated tests override `HOME` and unset `XDG_CONFIG_HOME`. `make test` stays
green on macOS and Ubuntu. Shell is linted with `shellcheck -S warning`
(`install/packages.sh` and `tests/test-packages.sh` join the CI gate set).

## Documentation

- README: state that `profile` selects the **link set**; package installation
  is a separate opt-in operation whose tier **defaults to the profile** and is
  overridable with `--packages`. Document each tier's package intent, the
  Homebrew `brew.env` behavior, and the Ubuntu required-vs-optional split.
  Coordinate with DOC-01's safe-install framing; keep the claims honest.
- Mark `docs/REVIEW-2026-07-14.md` PACKAGE-01, HOMEBREW-01, UBUNTU-02, DOC-02
  Resolved with the fixing commit, matching the existing
  `Resolved: <date> by <commit>` style. Update the Phase 2 remediation list.
- `CLAUDE.md` note on adding a package (add a `[[package]]` to
  `packages.toml`), mirroring the "adding a config" manifest note.

## Out of scope

- Per-`bin`-script or per-package platform fields beyond implicit gating.
- Reworking macOS defaults/hardening (separate findings, already resolved).
- Mason/Neovim tool version pinning (Phase 3).
- Ubuntu package version pinning.
- Making the imperative extras themselves declarative (they stay as code).

## Definition of done

- `profile` clearly means link-set; package installation is a distinct,
  explicit, tier-aware operation with `--packages` + profile-default —
  PACKAGE-01 resolved.
- `packages.toml` + `packages.sh` provide a pure, tested selection function;
  `Brewfile-min`/`Brewfile-all` removed.
- `brew.env` is the only Homebrew env file, linked before `brew bundle` at every
  tier; the undocumented `~/.config/homebrew/config` write is gone;
  `homebrew` removed from the link manifest — HOMEBREW-01 resolved.
- Ubuntu separates required (atomic apt) from optional (retried, HTTPS,
  summarized, non-aborting) extras — UBUNTU-02 resolved.
- README accurately describes link vs package behavior per profile/tier —
  DOC-02 resolved.
- `make test` green with new package-selection and executor-planning coverage.
- Addressed review entries marked Resolved with the fixing commit.
