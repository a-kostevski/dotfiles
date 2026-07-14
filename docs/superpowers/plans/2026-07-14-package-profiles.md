# Separate package installation from link profiles — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement task-by-task. Steps use checkbox (`- [ ]`) syntax.

**Goal:** Make `profile` mean link-set only, and turn package installation into a distinct, tier-aware, opt-in operation driven by a declarative `install/packages.toml` with a pure, testable selection function.

**Architecture:** New `install/packages.toml` (data) + `install/packages.sh` (awk reader + pure selection), mirroring the shipped `install/manifest.toml`/`install/manifest.sh` link manifest. The imperative tail (Ubuntu third-party repos, `curl|sh` installers, Neovim archive) stays as explicit, retryable installer code. macOS package installer owns `brew.env`. Ubuntu splits a required atomic apt install from optional, retried, summarized extras.

**Tech Stack:** Bash, awk (no jq/yq), the existing `tests/lib.sh` harness (`assert_eq`/`assert_contains`), `shellcheck -S warning`.

## Context

`docs/REVIEW-2026-07-14.md` Phase 2 flags that "profile" conflates linking and package installation. macOS `minimal`/`standard` share `Brewfile-min` (installs nvim/node/python despite "minimal = git/zsh/tmux"); Ubuntu ignores the profile entirely. `brew.env` is linked only by the `full` link profile and only after the first `brew bundle` (HOMEBREW-01), and the installer writes an undocumented `~/.config/homebrew/config`. Ubuntu's `set -euo pipefail` lets a transient network failure (eza repo over HTTP, `thefuck`) abort mid-run (UBUNTU-02). This plan resolves **PACKAGE-01, HOMEBREW-01, UBUNTU-02, DOC-02**. Design spec: `docs/superpowers/specs/2026-07-14-package-profiles-design.md` (approved, commit `11cd301`).

## Global Constraints

- Valid **package tiers**: `minimal | standard | full` (the `all` link profile maps to `full` packages). Link profiles remain `minimal | standard | full | all`.
- Never run real installs/sudo/network in tests; test pure selection + stubbed planning only (stub pattern: `tests/test-macos-defaults.sh`).
- Isolated tests override `HOME` and **unset `XDG_CONFIG_HOME`**.
- Manifest reader: constrained TOML subset, awk only, no jq/yq — mirror `install/manifest.sh` exactly.
- Lint gate covers `install/*.sh` and `tests/*.sh` automatically (`Makefile` `.lint-shell`). `make test` must stay green on macOS and Ubuntu.
- Do not commit/push unless asked. Feature branch `package-profiles` (already created).

## File Structure

- Create `install/packages.toml` — package data (tiers + `brew`/`cask`/`apt` names).
- Create `install/packages.sh` — awk reader, `packages_select`, `validate_tier`, `resolve_package_tier`.
- Create `tests/test-packages.sh` — reader unit tests + stubbed executor-planning tests.
- Modify `install/lib.sh` — add `retry`, `run_optional_step`, `report_optional_failures`.
- Modify `install/homebrew.sh` — `brew.env` first, generate Brewfile from selection, delete `configure_homebrew`/`get_brewfile_for_profile`.
- Modify `install/install-ubuntu.sh` — required atomic apt from selection; optional retryable extras; HTTPS eza.
- Modify `bootstrap.sh` — `--packages` flag, `PACKAGE_TIER` resolve/validate/export, usage + summary; source `packages.sh`.
- Modify `install/manifest.toml` — remove the `homebrew` link entry.
- Delete `config/homebrew/Brewfile-min`, `config/homebrew/Brewfile-all`.
- Modify `README.md`, `docs/REVIEW-2026-07-14.md`, `CLAUDE.md` — docs (CLAUDE.md is gitignored / machine-local).

---

### Task 1: Package manifest data + reader (parse + `packages_select`)

**Files:**
- Create: `install/packages.toml`
- Create: `install/packages.sh`
- Test: `tests/test-packages.sh`

**Interfaces:**
- Produces: `packages_records()` → `name|tiers|brew|cask|apt` lines; `packages_select <tier> <field>` where `field ∈ {brew,cask,apt}` → non-empty field values (one per line) for packages whose `tiers` include `<tier>`.

**`install/packages.toml`** (concrete starting content; apt names chosen to match today's Ubuntu behavior):

```toml
# Declarative package manifest. One [[package]] per tool.
#   name   unique id / summary label
#   tiers  subset of ["minimal","standard","full"] (list every tier it belongs to)
#   brew   macOS Homebrew formula ("" = skip on macOS)
#   cask   macOS Homebrew cask     ("" = none)
#   apt    Ubuntu apt package      ("" = skip / handled by an imperative extra)

[[package]]
name = "git"
tiers = ["minimal", "standard", "full"]
brew = "git"
cask = ""
apt = "git"

[[package]]
name = "git-lfs"
tiers = ["minimal", "standard", "full"]
brew = "git-lfs"
cask = ""
apt = "git-lfs"

[[package]]
name = "curl"
tiers = ["minimal", "standard", "full"]
brew = "curl"
cask = ""
apt = "curl"

[[package]]
name = "wget"
tiers = ["minimal", "standard", "full"]
brew = "wget"
cask = ""
apt = "wget"

[[package]]
name = "zsh"
tiers = ["minimal", "standard", "full"]
brew = "zsh"
cask = ""
apt = "zsh"

[[package]]
name = "tmux"
tiers = ["minimal", "standard", "full"]
brew = "tmux"
cask = ""
apt = "tmux"

[[package]]
name = "build-essential"
tiers = ["standard", "full"]
brew = ""
cask = ""
apt = "build-essential"

[[package]]
name = "software-properties-common"
tiers = ["standard", "full"]
brew = ""
cask = ""
apt = "software-properties-common"

[[package]]
name = "coreutils"
tiers = ["standard", "full"]
brew = "coreutils"
cask = ""
apt = ""

[[package]]
name = "findutils"
tiers = ["standard", "full"]
brew = "findutils"
cask = ""
apt = ""

[[package]]
name = "gnu-sed"
tiers = ["standard", "full"]
brew = "gnu-sed"
cask = ""
apt = ""

[[package]]
name = "grep"
tiers = ["standard", "full"]
brew = "grep"
cask = ""
apt = ""

[[package]]
name = "ripgrep"
tiers = ["standard", "full"]
brew = "ripgrep"
cask = ""
apt = "ripgrep"

[[package]]
name = "fd"
tiers = ["standard", "full"]
brew = "fd"
cask = ""
apt = "fd-find"

[[package]]
name = "fzf"
tiers = ["standard", "full"]
brew = "fzf"
cask = ""
apt = "fzf"

[[package]]
name = "jq"
tiers = ["standard", "full"]
brew = "jq"
cask = ""
apt = "jq"

[[package]]
name = "tree"
tiers = ["standard", "full"]
brew = "tree"
cask = ""
apt = "tree"

[[package]]
name = "bat"
tiers = ["standard", "full"]
brew = "bat"
cask = ""
apt = "bat"

[[package]]
name = "htop"
tiers = ["standard", "full"]
brew = "htop"
cask = ""
apt = "htop"

[[package]]
name = "unzip"
tiers = ["standard", "full"]
brew = ""
cask = ""
apt = "unzip"

[[package]]
name = "xclip"
tiers = ["standard", "full"]
brew = ""
cask = ""
apt = "xclip"

[[package]]
name = "python"
tiers = ["standard", "full"]
brew = "python"
cask = ""
apt = "python3-pip"

[[package]]
name = "node"
tiers = ["standard", "full"]
brew = "node"
cask = ""
apt = ""

# neovim (ubuntu via archive extra) and eza (ubuntu via apt-repo extra) carry
# empty apt on purpose.
[[package]]
name = "neovim"
tiers = ["standard", "full"]
brew = "neovim"
cask = ""
apt = ""

[[package]]
name = "eza"
tiers = ["standard", "full"]
brew = "eza"
cask = ""
apt = ""

[[package]]
name = "uv"
tiers = ["standard", "full"]
brew = "uv"
cask = ""
apt = ""

# ---- full-only formulae ----
[[package]]
name = "gh"
tiers = ["full"]
brew = "gh"
cask = ""
apt = ""

[[package]]
name = "git-delta"
tiers = ["full"]
brew = "git-delta"
cask = ""
apt = ""

[[package]]
name = "clang-format"
tiers = ["full"]
brew = "clang-format"
cask = ""
apt = ""

# (Remaining Brewfile-all formulae — cmake, cppcheck, llvm, colordiff, make,
#  languages ruby/rust/go/openjdk/perl/python@3.12, pyenv, pyenv-virtualenv,
#  pnpm, nmap, netcat, nghttp2, aria2, gnupg, lynis, ffmpeg, imagemagick,
#  ghostscript, and system libs openssl@3/pcre/readline/sqlite/xz/zlib/gettext/
#  libssh2/libusb/libxml2/libxslt/libzip — each as its own [[package]], tiers=["full"],
#  brew=<name>, apt="".)

# ---- full-only casks (macOS) ----
[[package]]
name = "1password"
tiers = ["full"]
brew = ""
cask = "1password"
apt = ""

[[package]]
name = "kitty"
tiers = ["full"]
brew = ""
cask = "kitty"
apt = ""

# (Remaining Brewfile-all casks — 1password-cli, alfred, appcleaner,
#  brave-browser, daisydisk, flux, font-hack-nerd-font, little-snitch,
#  the-unarchiver, transmission, vlc, wireshark, docker, postman, mullvadvpn,
#  tor-browser, knockknock, launchcontrol, taskexplorer — each tiers=["full"],
#  cask=<name>.)
```

> Implementer note: expand the two "(Remaining …)" comments into full `[[package]]` entries, one per name listed, copying the exact names from `config/homebrew/Brewfile-all` before deleting it.

**`install/packages.sh`** (mirror `install/manifest.sh` header + awk style):

```bash
#!/usr/bin/env bash

# Declarative package manifest reader. All TOML parsing is isolated in
# _packages_awk; the rest consumes pipe-delimited records. Pure: no network,
# sudo, or filesystem mutation.

if [[ -z "${dot_title:-}" ]]; then
  source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
fi

PACKAGES_TOML="${PACKAGES_TOML:-${dot_root:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)}/install/packages.toml}"

_packages_awk() {
  awk '
    function flush() {
      if (have) printf "%s|%s|%s|%s|%s\n", p["name"], p["tiers"], p["brew"], p["cask"], p["apt"]
      have = 0; delete p
    }
    /^[[:space:]]*#/ { next }
    /^[[:space:]]*\[\[package\]\]/ { flush(); have = 1; next }
    /^[[:space:]]*[a-z][a-z-]*[[:space:]]*=/ {
      key = $1
      eq = index($0, "="); val = substr($0, eq + 1)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", key)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", val)
      if (val ~ /^\[/) { gsub(/^\[|\]$/, "", val); gsub(/"/, "", val); gsub(/[[:space:]]+/, "", val) }
      else { gsub(/^"|"$/, "", val) }
      p[key] = val; have = 1; next
    }
    END { flush() }
  ' "$1"
}

packages_records() {
  [[ -f "$PACKAGES_TOML" ]] || { dot_error "Package manifest not found: $PACKAGES_TOML"; return 1; }
  _packages_awk "$PACKAGES_TOML"
}

_packages_csv_has() {
  local needle="$1" csv="$2" tok
  local IFS=,
  for tok in $csv; do [[ "$tok" == "$needle" ]] && return 0; done
  return 1
}

# packages_select <tier> <field>   field ∈ brew|cask|apt
packages_select() {
  local tier="$1" field="$2"
  local name tiers brew cask apt val
  while IFS='|' read -r name tiers brew cask apt; do
    [[ -z "$name" ]] && continue
    _packages_csv_has "$tier" "$tiers" || continue
    case "$field" in
      brew) val="$brew" ;;
      cask) val="$cask" ;;
      apt) val="$apt" ;;
      *) continue ;;
    esac
    [[ -n "$val" ]] && printf '%s\n' "$val"
  done < <(packages_records)
}
```

- [ ] **Step 1: Write failing reader tests.** Create `tests/test-packages.sh` (header mirrors `tests/test-manifest.sh`: set `REPO_ROOT`, `cd`, source `tests/lib.sh`, `export dot_root="$REPO_ROOT"`, source `install/lib.sh` then `install/packages.sh`). Assert against the real `install/packages.toml`:

```bash
echo "== packages_records parsing =="
records="$(packages_records)"
assert_contains "git record parsed" "git|minimal,standard,full|git||git" "$records"
assert_contains "neovim has empty apt" "neovim|standard,full|neovim||" "$records"
assert_contains "kitty is a cask" "kitty|full||kitty|" "$records"

echo "== packages_select tier + field =="
min_brew="$(packages_select minimal brew)"
assert_contains "minimal brew has git" "git" "$min_brew"
assert_eq "minimal brew excludes neovim" "" "$(grep -x neovim <<<"$min_brew" || true)"
assert_eq "minimal brew excludes node" "" "$(grep -x node <<<"$min_brew" || true)"

std_brew="$(packages_select standard brew)"
assert_contains "standard brew includes neovim" "neovim" "$std_brew"

std_apt="$(packages_select standard apt)"
assert_contains "standard apt uses fd-find" "fd-find" "$std_apt"
assert_eq "standard apt excludes neovim (archive extra)" "" "$(grep -x neovim <<<"$std_apt" || true)"
assert_eq "standard apt excludes eza (repo extra)" "" "$(grep -x eza <<<"$std_apt" || true)"

full_cask="$(packages_select full cask)"
assert_contains "full cask includes kitty" "kitty" "$full_cask"
min_cask="$(packages_select minimal cask)"
assert_eq "minimal has no casks" "" "$min_cask"

echo
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
```

- [ ] **Step 2: Run, verify fail.** `bash tests/test-packages.sh` → fails (no `install/packages.sh`).
- [ ] **Step 3: Implement.** Create `install/packages.toml` (expand both "(Remaining …)" blocks fully) and `install/packages.sh` as above.
- [ ] **Step 4: Run, verify pass.** `bash tests/test-packages.sh` → all pass. Then `shellcheck -S warning install/packages.sh tests/test-packages.sh`.
- [ ] **Step 5: Commit.** `git add install/packages.toml install/packages.sh tests/test-packages.sh && git commit -m "packages: add declarative package manifest and reader"`

---

### Task 2: Tier validation + resolution

**Files:**
- Modify: `install/packages.sh` (append)
- Test: `tests/test-packages.sh` (extend)

**Interfaces:**
- Produces: `validate_tier <tier>` (0 for `minimal|standard|full`); `resolve_package_tier <profile> [override]` → prints resolved tier (`all→full`, override wins), returns non-zero on invalid.

```bash
validate_tier() {
  case "$1" in
    minimal | standard | full) return 0 ;;
    *)
      dot_error "Invalid package tier: $1"
      dot_error "Valid tiers: minimal, standard, full"
      return 1
      ;;
  esac
}

# resolve_package_tier <profile> [override]
resolve_package_tier() {
  local profile="$1" override="${2:-}" tier
  if [[ -n "$override" ]]; then
    tier="$override"
  else
    case "$profile" in
      minimal) tier="minimal" ;;
      standard) tier="standard" ;;
      full | all) tier="full" ;;
      *) tier="minimal" ;;
    esac
  fi
  validate_tier "$tier" || return 1
  printf '%s' "$tier"
}
```

- [ ] **Step 1: Write failing tests** (extend `tests/test-packages.sh` before the summary):

```bash
echo "== validate_tier / resolve_package_tier =="
validate_tier minimal && vt_min=0 || vt_min=1
assert_eq "validate_tier accepts minimal" "0" "$vt_min"
validate_tier bogus 2>/dev/null && vt_bad=0 || vt_bad=1
assert_eq "validate_tier rejects bogus" "1" "$vt_bad"
assert_eq "profile standard -> standard packages" "standard" "$(resolve_package_tier standard)"
assert_eq "profile all -> full packages" "full" "$(resolve_package_tier all)"
assert_eq "override wins over profile" "full" "$(resolve_package_tier minimal full)"
```

- [ ] **Step 2: Run, verify fail.** `bash tests/test-packages.sh` → new asserts fail.
- [ ] **Step 3: Implement.** Append both functions to `install/packages.sh`.
- [ ] **Step 4: Run, verify pass.** `bash tests/test-packages.sh` + `shellcheck -S warning install/packages.sh`.
- [ ] **Step 5: Commit.** `git add install/packages.sh tests/test-packages.sh && git commit -m "packages: add tier validation and profile->tier resolution"`

---

### Task 3: `retry` + optional-step helpers in `lib.sh`

**Files:**
- Modify: `install/lib.sh` (append after `safe_sudo`)
- Test: `tests/test-packages.sh` (extend) — or a dedicated section; keep in one file.

**Interfaces:**
- Produces: `retry <attempts> <delay> -- <cmd...>` (returns last status; no `sleep` under `DRY_RUN`); `run_optional_step <name> <cmd...>` (always returns 0; on failure appends `<name>` to `OPTIONAL_FAILURES`); `report_optional_failures` (warns with the list, returns 0). `OPTIONAL_FAILURES` is a module-level array initialized empty.

```bash
# Retry a command up to <attempts> times with <delay>s between tries.
# retry 3 5 -- some_cmd arg
retry() {
  local attempts="$1" delay="$2"
  shift 2
  [[ "${1:-}" == "--" ]] && shift
  local n=1
  while true; do
    if "$@"; then return 0; fi
    (( n >= attempts )) && return 1
    n=$((n + 1))
    [[ -z "${DRY_RUN:-}" ]] && sleep "$delay"
  done
}

# Optional steps: never abort the run; collect failures for a summary.
OPTIONAL_FAILURES=()
run_optional_step() {
  local name="$1"
  shift
  if "$@"; then
    return 0
  fi
  dot_warning "Optional step failed: $name"
  OPTIONAL_FAILURES+=("$name")
  return 0
}
report_optional_failures() {
  if (( ${#OPTIONAL_FAILURES[@]} > 0 )); then
    dot_warning "Optional steps that failed: ${OPTIONAL_FAILURES[*]}"
  fi
  return 0
}
```

- [ ] **Step 1: Write failing tests** (extend `tests/test-packages.sh`; sources `install/lib.sh` already):

```bash
echo "== retry / optional steps =="
_fail_twice_count=0
_fail_twice() { _fail_twice_count=$((_fail_twice_count+1)); (( _fail_twice_count >= 3 )); }
DRY_RUN= retry 5 0 -- _fail_twice && r_ok=0 || r_ok=1
assert_eq "retry succeeds after transient failures" "0" "$r_ok"

_always_fail() { return 1; }
DRY_RUN= retry 2 0 -- _always_fail && r_bad=0 || r_bad=1
assert_eq "retry gives up after attempts" "1" "$r_bad"

OPTIONAL_FAILURES=()
run_optional_step "widget" _always_fail
assert_eq "optional failure does not abort" "widget" "${OPTIONAL_FAILURES[*]}"
summary="$(report_optional_failures 2>&1)"
assert_contains "summary lists failed step" "widget" "$summary"
```

- [ ] **Step 2: Run, verify fail.** `bash tests/test-packages.sh`.
- [ ] **Step 3: Implement.** Append the three helpers to `install/lib.sh`.
- [ ] **Step 4: Run, verify pass.** `bash tests/test-packages.sh` + `shellcheck -S warning install/lib.sh`.
- [ ] **Step 5: Commit.** `git add install/lib.sh tests/test-packages.sh && git commit -m "lib: add retry and optional-step summary helpers"`

---

### Task 4: `--packages` flag + `PACKAGE_TIER` wiring in `bootstrap.sh`

**Files:**
- Modify: `bootstrap.sh` (source line ~55; globals ~40; `usage`; `parse_args`; post-parse validation; exports ~367; `show_summary`)
- Test: `tests/test-bootstrap.sh` (add cases following its existing style)

**Interfaces:**
- Consumes: `validate_tier`, `resolve_package_tier` (Task 2).
- Produces: exported `PACKAGE_TIER` for the installers.

Changes:
1. After `source "$SCRIPT_DIR/install/manifest.sh"` add `source "$SCRIPT_DIR/install/packages.sh"`.
2. Globals: add `declare -g PACKAGE_TIER=""` and `declare -g PACKAGE_TIER_OVERRIDE=""`.
3. `parse_args` new case:

```bash
      --packages)
        PACKAGE_TIER_OVERRIDE="${2:-}"
        [[ -z "$PACKAGE_TIER_OVERRIDE" ]] && dot_error "--packages requires a tier" && exit 1
        validate_tier "$PACKAGE_TIER_OVERRIDE" || exit 1
        shift 2
        ;;
```

4. Post-parse validation (near the `--skip-install`/`--sync` checks): error if `--packages` given without `--install-packages`:

```bash
  if [[ -n "$PACKAGE_TIER_OVERRIDE" ]] && [[ "$INSTALL_PACKAGES" != "true" ]]; then
    dot_error "--packages requires --install-packages"
    exit 2
  fi
```

5. After OS detection / profile validation and before `run_os_installation`, resolve the tier:

```bash
  PACKAGE_TIER="$(resolve_package_tier "$PROFILE" "$PACKAGE_TIER_OVERRIDE")" || exit 1
```

6. Export: add `PACKAGE_TIER` to the `export ... INSTALL_PACKAGES ...` line.
7. `usage`: document `--packages <tier>` under OPTIONS and add an example (`$SCRIPT_NAME --install-packages --packages full`). Note packages default to the profile's tier.
8. `show_summary`: add `echo "  Package Tier:   $([[ "$INSTALL_PACKAGES" == "true" ]] && echo "$PACKAGE_TIER" || echo "Not requested")"`.

- [ ] **Step 1: Write failing tests** in `tests/test-bootstrap.sh` (match its harness; use `--dry-run` so nothing installs). Assert: `--packages full` without `--install-packages` exits non-zero with the guidance message; `--install-packages --packages full --dry-run` runs and the summary shows `Package Tier:   full`; `--install-packages --profile standard --dry-run` summary shows `standard`; `--packages bogus` is rejected by `validate_tier`. (Follow the existing pattern in `tests/test-bootstrap.sh` for invoking bootstrap and capturing output/exit code.)
- [ ] **Step 2: Run, verify fail.** `bash tests/test-bootstrap.sh`.
- [ ] **Step 3: Implement** the eight edits above.
- [ ] **Step 4: Run, verify pass.** `bash tests/test-bootstrap.sh` + `shellcheck -S warning bootstrap.sh`.
- [ ] **Step 5: Commit.** `git add bootstrap.sh tests/test-bootstrap.sh && git commit -m "bootstrap: add --packages tier flag decoupled from link profile"`

---

### Task 5: macOS executor — `brew.env` first + generated Brewfile

**Files:**
- Modify: `install/homebrew.sh` (rewrite `configure_homebrew` → removed; `get_brewfile_for_profile`/`install_packages` → selection-driven; `main`)
- Test: `tests/test-packages.sh` (extend with stubbed planning)
- Delete (Task 7): `config/homebrew/Brewfile-min`, `Brewfile-all`

**Interfaces:**
- Consumes: `packages_select` (Task 1), `PACKAGE_TIER`, `create_symlink` (from `install/symlinks.sh`).
- Produces: `generate_brewfile <tier> <outfile>` (pure: writes `brew "x"` / `cask "y"` lines), `link_brew_env` (links `config/homebrew/brew.env` → `~/.config/homebrew/brew.env`).

Rewrite so `install/homebrew.sh`:
- Sources `packages.sh` if not loaded: `if ! declare -f packages_select >/dev/null; then source "$dot_root/install/packages.sh"; fi`.
- **Deletes** `configure_homebrew` (and its `~/.config/homebrew/config` write) and `get_brewfile_for_profile`.
- Adds:

```bash
link_brew_env() {
  local src="$dot_root/config/homebrew/brew.env"
  local dest="$HOME/.config/homebrew/brew.env"
  validate_file "$src" "Homebrew environment file" || return 1
  create_symlink "$src" "$dest"
}

# Pure: emit a Brewfile for a tier. Testable without brew.
generate_brewfile() {
  local tier="$1" out="$2" name
  : >"$out"
  while IFS= read -r name; do [[ -n "$name" ]] && printf 'brew "%s"\n' "$name" >>"$out"; done < <(packages_select "$tier" brew)
  while IFS= read -r name; do [[ -n "$name" ]] && printf 'cask "%s"\n' "$name" >>"$out"; done < <(packages_select "$tier" cask)
}

install_packages() {
  local tier="${PACKAGE_TIER:-minimal}"
  local brewfile; brewfile="$(mktemp)"
  generate_brewfile "$tier" "$brewfile"
  dot_info "Installing Homebrew packages ($tier tier)..."
  if execute_cmd "brew bundle --file='$brewfile'"; then
    dot_success "Installed Homebrew packages"
    rm -f "$brewfile"
  else
    dot_error "Failed to install some Homebrew packages"
    rm -f "$brewfile"
    return 1
  fi
}

main() {
  install_homebrew || return 1
  link_brew_env || return 1     # before any brew bundle
  install_packages || return 1
  return 0
}
```

- [ ] **Step 1: Write failing planning test** (extend `tests/test-packages.sh`): set `dot_root="$REPO_ROOT"`, `PACKAGE_TIER=standard`, source `install/symlinks.sh` + `install/packages.sh` + `install/homebrew.sh` (guard: `install_homebrew` runs `brew`, so only call `generate_brewfile` here — do **not** call `main`). Then:

```bash
echo "== macOS Brewfile generation =="
bf="$(mktemp)"
generate_brewfile standard "$bf"
gen="$(cat "$bf")"; rm -f "$bf"
assert_contains "standard Brewfile has neovim formula" 'brew "neovim"' "$gen"
assert_eq "standard Brewfile has no casks" "" "$(grep '^cask ' <<<"$gen" || true)"
bf2="$(mktemp)"; generate_brewfile full "$bf2"; genf="$(cat "$bf2")"; rm -f "$bf2"
assert_contains "full Brewfile includes kitty cask" 'cask "kitty"' "$genf"
```

  Sourcing `homebrew.sh` executes `main "$@"` at file end today — **guard it**: change the bottom of `homebrew.sh` from bare `main "$@"` to `if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then main "$@"; fi` so the test (and `install-macos.sh`, which calls `main` explicitly? verify) can source without running brew. Confirm `install/install-macos.sh` calls `main`/`run_macos_provisioning` appropriately after this guard — it currently `source`s `homebrew.sh` and relies on the trailing `main`. After guarding, `install_macos_packages` must call `main` explicitly (add `main` after the `source` line in `install_macos_packages`).
- [ ] **Step 2: Run, verify fail.** `bash tests/test-packages.sh`.
- [ ] **Step 3: Implement** the rewrite + source guard + explicit `main` call in `install-macos.sh`.
- [ ] **Step 4: Run, verify pass.** `bash tests/test-packages.sh` + `shellcheck -S warning install/homebrew.sh install/install-macos.sh`.
- [ ] **Step 5: Commit.** `git add install/homebrew.sh install/install-macos.sh tests/test-packages.sh && git commit -m "homebrew: link brew.env before bundle; generate Brewfile from tier selection"`

---

### Task 6: Ubuntu executor — required atomic apt + optional retryable extras

**Files:**
- Modify: `install/install-ubuntu.sh` (`install_ubuntu_packages` rewrite; extract extras into functions; HTTPS eza)
- Test: `tests/test-packages.sh` (extend with stubbed planning)

**Interfaces:**
- Consumes: `packages_select` (apt field), `retry`, `run_optional_step`, `report_optional_failures`, `PACKAGE_TIER`.
- Produces: `ubuntu_required_apt <tier>` (prints the space-joined apt set — pure/testable); extras `install_eza`, `install_uv`, `install_thefuck` (+ existing `install_neovim`) each returning non-zero on failure.

Rewrite:
- Add a pure selector:

```bash
ubuntu_required_apt() {
  packages_select "$1" apt | tr '\n' ' '
}
```

- Restructure `install_ubuntu_packages`:

```bash
install_ubuntu_packages() {
  dot_title "Installing packages for Ubuntu"
  HOME=${HOME:-$(get_default_home)}
  local tier="${PACKAGE_TIER:-minimal}"

  # Required base — atomic; a failure here is a real failure.
  dot_info "Updating package lists..."
  execute_cmd "sudo apt-get update"
  local apt_pkgs; apt_pkgs="$(ubuntu_required_apt "$tier")"
  dot_info "Installing required apt packages ($tier tier)..."
  execute_cmd "sudo apt-get install -y $apt_pkgs"

  # Optional extras — retried, never abort, summarized. Standard/full only.
  case "$tier" in
    standard | full)
      run_optional_step "neovim" retry 3 5 -- install_neovim
      run_optional_step "eza" retry 3 5 -- install_eza
      run_optional_step "uv" retry 3 5 -- install_uv
      run_optional_step "thefuck" retry 3 5 -- install_thefuck
      ;;
  esac

  create_tool_symlinks   # fd/bat compat; local, cheap
  report_optional_failures
  dot_success "Ubuntu package setup completed"
}
```

- Extract the eza block into `install_eza()` using **HTTPS** and returning non-zero on failure:

```bash
install_eza() {
  command_exists eza && return 0
  execute_cmd "sudo mkdir -p /etc/apt/keyrings" || return 1
  execute_cmd "wget -qO- https://raw.githubusercontent.com/eza-community/eza/main/deb.asc | sudo gpg --dearmor -o /etc/apt/keyrings/gierens.gpg" || return 1
  execute_cmd "echo \"deb [signed-by=/etc/apt/keyrings/gierens.gpg] https://deb.gierens.de stable main\" | sudo tee /etc/apt/sources.list.d/gierens.list" || return 1
  execute_cmd "sudo chmod 644 /etc/apt/keyrings/gierens.gpg /etc/apt/sources.list.d/gierens.list" || return 1
  execute_cmd "sudo apt-get update" || return 1
  execute_cmd "sudo apt-get install -y eza" || return 1
}
```

- Extract `install_uv()` (from current uv block, `|| return 1`) and `install_thefuck()` (keep the `uv_command` helper it depends on; `|| return 1`). Extract the fd/bat symlink block into `create_tool_symlinks()`. Keep `install_neovim` as-is (already returns non-zero on failure).

- [ ] **Step 1: Write failing planning test** (extend `tests/test-packages.sh`): source `install/lib.sh`, `install/packages.sh`, `install/install-ubuntu.sh` (its trailing block only errors when executed directly, safe to source). Then:

```bash
echo "== Ubuntu apt selection + optional failures =="
assert_contains "minimal apt has git" "git" "$(ubuntu_required_apt minimal)"
assert_eq "minimal apt excludes ripgrep" "" "$(grep -ow ripgrep <<<"$(ubuntu_required_apt minimal)" || true)"
assert_contains "standard apt uses fd-find" "fd-find" "$(ubuntu_required_apt standard)"

OPTIONAL_FAILURES=()
_boom() { return 1; }
run_optional_step "eza" retry 2 0 -- _boom
assert_eq "failed optional eza recorded, run not aborted" "eza" "${OPTIONAL_FAILURES[*]}"

grep -q "https://deb.gierens.de" "$REPO_ROOT/install/install-ubuntu.sh" && https_ok=0 || https_ok=1
assert_eq "eza repo uses HTTPS" "0" "$https_ok"
assert_eq "no HTTP eza repo remains" "" "$(grep -o 'http://deb.gierens.de' "$REPO_ROOT/install/install-ubuntu.sh" || true)"
```

- [ ] **Step 2: Run, verify fail.** `bash tests/test-packages.sh`.
- [ ] **Step 3: Implement** the rewrite + extracted functions + HTTPS.
- [ ] **Step 4: Run, verify pass.** `bash tests/test-packages.sh` + `shellcheck -S warning install/install-ubuntu.sh`.
- [ ] **Step 5: Commit.** `git add install/install-ubuntu.sh tests/test-packages.sh && git commit -m "ubuntu: split required apt from optional retryable extras; HTTPS eza repo"`

---

### Task 7: Remove `homebrew` link entry + delete Brewfiles

**Files:**
- Modify: `install/manifest.toml` (remove the `[[entry]] name = "homebrew"` block, lines ~116–122)
- Delete: `config/homebrew/Brewfile-min`, `config/homebrew/Brewfile-all`
- Modify: `tests/test-manifest.sh` / `tests/test-bootstrap.sh` / `tests/test-uninstall.sh` **only if** they reference `homebrew` as a linked component (grep first).

- [ ] **Step 1: Check references.** `grep -rn "homebrew" tests/ install/manifest.toml` and `grep -rn "Brewfile" . --include='*.sh' --include='Makefile' --include='*.md'`. Note every hit to update (e.g. `is_ignored`'s `Brewfile*.lock.json` pattern in `lib.sh` can stay harmlessly).
- [ ] **Step 2: Write/adjust failing assertion.** In `tests/test-manifest.sh`, assert `homebrew` is **not** a full/macos component: `assert_eq "homebrew not a link component" "" "$(grep '^homebrew|' <<<"$(manifest_select full macos)" || true)"`.
- [ ] **Step 3: Run, verify fail.** `bash tests/test-manifest.sh`.
- [ ] **Step 4: Implement.** Remove the manifest entry; `git rm config/homebrew/Brewfile-min config/homebrew/Brewfile-all`; update any test references found in Step 1.
- [ ] **Step 5: Run, verify pass.** `make test` (full suite) + `shellcheck -S warning install/*.sh tests/*.sh bootstrap.sh bin/dotfiles`.
- [ ] **Step 6: Commit.** `git add -A && git commit -m "packages: drop homebrew link entry and static Brewfiles"`

---

### Task 8: Documentation + review resolution

**Files:**
- Modify: `README.md`, `docs/REVIEW-2026-07-14.md`, `CLAUDE.md` (gitignored — machine-local)

- [ ] **Step 1: README.** State that `profile` selects the **link set**; package installation is a separate opt-in (`--install-packages`) whose **tier defaults to the profile** and is overridable with `--packages <minimal|standard|full>`. Document what each tier installs (honest, matching `packages.toml`), the `brew.env` behavior, and the Ubuntu required-vs-optional split. Keep the safe link-only path primary (DOC-01 framing).
- [ ] **Step 2: REVIEW doc.** Mark **PACKAGE-01, HOMEBREW-01, UBUNTU-02, DOC-02** `Resolved: 2026-07-14 by <commit>` in the existing style; tick the Phase 2 remediation list item "Separate package profiles or document them as independent from link profiles."
- [ ] **Step 3: CLAUDE.md.** Add a short "adding a package" note (append a `[[package]]` to `install/packages.toml`), mirroring the "adding a config" manifest note.
- [ ] **Step 4: Commit.** `git add README.md docs/REVIEW-2026-07-14.md CLAUDE.md && git commit -m "docs: describe link profiles vs package tiers; mark PACKAGE-01/HOMEBREW-01/UBUNTU-02/DOC-02 resolved"` (fill the resolved-by hashes after the code commits land; may amend Step 2 hashes in a follow-up).

---

## Verification

- **Unit + planning:** `bash tests/test-packages.sh` — reader parsing, tier/field selection, `validate_tier`/`resolve_package_tier`, `retry`/optional-step behavior, macOS Brewfile generation, Ubuntu apt selection + HTTPS + non-aborting optional failure. All pure/stubbed (no network/sudo).
- **Full suite:** `make test` green on macOS and (via CI) Ubuntu. `tests/test-bootstrap.sh` covers the new `--packages` flag and summary.
- **Lint:** `make .lint-shell` (`shellcheck -S warning` over `install/*.sh`, `tests/*.sh`, `bootstrap.sh`, `bin/dotfiles`, hooks) passes.
- **Dry-run smoke (manual, no mutation):** `./bootstrap.sh --install-packages --profile standard --dry-run` prints `Package Tier: standard`, a generated `brew bundle` (macOS) or required apt list (Ubuntu), and `[DRY-RUN]` for every side-effecting command; `./bootstrap.sh --packages full --dry-run` errors "`--packages requires --install-packages`".
- **Behavior checks:** `minimal` tier no longer selects neovim/node/python (PACKAGE-01); `brew.env` links before `brew bundle` and the `~/.config/homebrew/config` write is gone (HOMEBREW-01); a stubbed failing Ubuntu optional step is retried, does not abort, and appears in the summary; eza repo is HTTPS (UBUNTU-02); README tiers match `packages.toml` (DOC-02).

## Self-review notes

- **Spec coverage:** PACKAGE-01 → Tasks 1,5,6; HOMEBREW-01 → Task 5 (+ Task 7 link-entry removal); UBUNTU-02 → Tasks 3,6; DOC-02 → Task 8. Pure selection + planning tests satisfy TEST-04's intent.
- **Type consistency:** `packages_select <tier> <field>` (2 args; simplified from the spec's 3-arg form since OS is implied by field) used consistently in Tasks 1/5/6. `resolve_package_tier`, `generate_brewfile`, `ubuntu_required_apt`, `retry`/`run_optional_step`/`report_optional_failures` names match across producer/consumer tasks.
- **Watch item:** guarding `homebrew.sh`'s trailing `main "$@"` (Task 5) requires adding an explicit `main` call in `install-macos.sh:install_macos_packages`; verify no double-invocation.
