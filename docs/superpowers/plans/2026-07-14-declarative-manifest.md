# Declarative Source Manifest Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the four/five scattered source→destination derivations with one tracked declarative manifest that drives link, status, and uninstall; remove the dead profile/interactive/`--synced`/destination-flag surface.

**Architecture:** A data-only `install/manifest.toml` (constrained TOML subset) declares every component's source, destination, profile membership, and platform gating. A single reader module `install/manifest.sh` parses it with one isolated awk and exposes `manifest_links`/`manifest_components`/`manifest_component_links`/`manifest_component_exists`/`manifest_home_dests`. `bootstrap.sh` (link), `bin/dotfiles` (status, uninstall) all consume that API. The installed manifest (`~/.config/.dotfiles-manifest`) stays as the runtime record, written by `create_symlink` — it becomes the projection of the source manifest onto the machine.

**Tech Stack:** Bash 4+, awk, POSIX find; existing test harness in `tests/lib.sh`; ShellCheck.

## Global Constraints

- Bash 4+ required (`declare -gA`); entry points already guard this — do not break the guard.
- No runtime dependency on `jq`/`yq`. TOML parsing is one awk block, isolated in `install/manifest.sh`.
- Cross-platform: macOS and Ubuntu/Debian. Respect XDG paths (`${XDG_CONFIG_HOME:-$HOME/.config}`).
- Preserve S-01 (per-file symlinks + timestamped backups), S-02 (physical-path ownership uninstall + backup restore). Do not regress.
- `make test` must stay green after every task. `make test` runs every `tests/test-*.sh`.
- ShellCheck gate covers `bootstrap.sh install/*.sh bin/dotfiles tests/*.sh .githooks/*` — new `.sh` files must pass `shellcheck -S warning`.
- Never edit `~/.config/` directly. Tests drive isolated layouts by overriding `HOME`.
- Valid profiles after this work: `minimal | standard | full | all`. `custom` is rejected.
- Placeholder tokens in the manifest: `{XDG_CONFIG}` → `${XDG_CONFIG_HOME:-$HOME/.config}`, `{HOME}` → `$HOME`, `{BIN}` → `$HOME/.local/bin`.
- Commit after every task with a `Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>` trailer.

---

## File Structure

- `install/manifest.toml` (new) — the declarative entry set. Data only.
- `install/manifest.sh` (new) — the reader/API. All TOML parsing isolated here in one awk.
- `install/profiles.sh` (deleted in Task 6) — its two survivors (`validate_profile`, `get_profile_description`) move into `manifest.sh`.
- `install/symlinks.sh` (modified, Task 6) — remove `get_config_symlinks`, `get_synced_configs`, `has_synced_binaries`, `check_symlink_health`; keep create/check/clean/uninstall/manifest machinery.
- `bootstrap.sh` (modified, Task 3) — `link_configs`/`link_binaries` consume `manifest_links`; drop `--synced`, `--config-dest`, `--bin-dest`.
- `bin/dotfiles` (modified, Tasks 4–5) — `cmd_status` and `cmd_uninstall` consume the manifest API.
- `.githooks/post-checkout`, `.githooks/post-merge` (verified, Task 7) — already match `install/|bin/|bootstrap.sh`.
- `tests/test-manifest.sh` (new, Tasks 1–2) — reader unit tests.
- `tests/test-bootstrap.sh` (modified, Task 6) — swap removed-symbol tests for manifest equivalents.
- `config/defaults`, `config/security`, `config/ubuntu` (deleted, Task 7).
- `README.md`, `CLAUDE.md`, `docs/REVIEW-2026-07-14.md` (modified, Task 8).

---

### Task 1: Manifest data file + reader parse/select

**Files:**
- Create: `install/manifest.toml`
- Create: `install/manifest.sh`
- Test: `tests/test-manifest.sh`

**Interfaces:**
- Consumes: `install/lib.sh` (`is_ignored`, `dot_root`), `MANIFEST_TOML` env (defaults to `$dot_root/install/manifest.toml`).
- Produces:
  - `manifest_records` → prints all entries, one per line, `name|kind|src|dest|profiles_csv|platforms_csv` (placeholders and repo-relative src intact).
  - `manifest_select <profile> <os>` → same format, filtered to entries whose platform matches (`all` or `<os>`) and whose profile matches (`<profile>` in profiles csv, or `<profile>`==`all`).

- [ ] **Step 1: Write `install/manifest.toml`**

```toml
# Declarative source manifest for dotfiles.
# Columns per [[entry]]:
#   name       unique entry id
#   kind       "tree" (link every non-ignored file under src) | "file" (single file)
#   src        repo-relative source path
#   dest       destination; {XDG_CONFIG}=${XDG_CONFIG_HOME:-~/.config}, {HOME}=~, {BIN}=~/.local/bin
#   profiles   subset of ["minimal","standard","full"]; the "all" profile selects every entry
#   platforms  ["all"] or subset of ["macos","ubuntu"]
# A file entry whose src lives under a tree entry's src belongs to that tree's
# component and shadows itself out of the tree's file set.

[[entry]]
name = "git"
kind = "tree"
src = "config/git"
dest = "{XDG_CONFIG}/git"
profiles = ["minimal", "standard", "full"]
platforms = ["all"]

[[entry]]
name = "zsh"
kind = "tree"
src = "config/zsh"
dest = "{XDG_CONFIG}/zsh"
profiles = ["minimal", "standard", "full"]
platforms = ["all"]

[[entry]]
name = "zsh-env"
kind = "file"
src = "config/zsh/zshenv"
dest = "{HOME}/.zshenv"
profiles = ["minimal", "standard", "full"]
platforms = ["all"]

[[entry]]
name = "tmux"
kind = "tree"
src = "config/tmux"
dest = "{XDG_CONFIG}/tmux"
profiles = ["minimal", "standard", "full"]
platforms = ["all"]

[[entry]]
name = "nvim"
kind = "tree"
src = "config/nvim"
dest = "{XDG_CONFIG}/nvim"
profiles = ["standard", "full"]
platforms = ["all"]

[[entry]]
name = "bat"
kind = "tree"
src = "config/bat"
dest = "{XDG_CONFIG}/bat"
profiles = ["standard", "full"]
platforms = ["all"]

[[entry]]
name = "python"
kind = "tree"
src = "config/python"
dest = "{XDG_CONFIG}/python"
profiles = ["standard", "full"]
platforms = ["all"]

[[entry]]
name = "ripgrep"
kind = "tree"
src = "config/ripgrep"
dest = "{XDG_CONFIG}/ripgrep"
profiles = ["standard", "full"]
platforms = ["all"]

[[entry]]
name = "clang-format"
kind = "file"
src = "config/clang-format"
dest = "{HOME}/.clang-format"
profiles = ["full"]
platforms = ["all"]

[[entry]]
name = "curl"
kind = "file"
src = "config/.curlrc"
dest = "{HOME}/.curlrc"
profiles = ["full"]
platforms = ["all"]

[[entry]]
name = "lldb"
kind = "tree"
src = "config/lldb"
dest = "{XDG_CONFIG}/lldb"
profiles = ["full"]
platforms = ["all"]

[[entry]]
name = "lldb-init"
kind = "file"
src = "config/lldb/.lldbinit"
dest = "{HOME}/.lldbinit"
profiles = ["full"]
platforms = ["macos"]

[[entry]]
name = "op"
kind = "tree"
src = "config/op"
dest = "{XDG_CONFIG}/op"
profiles = ["full"]
platforms = ["all"]

[[entry]]
name = "homebrew"
kind = "tree"
src = "config/homebrew"
dest = "{XDG_CONFIG}/homebrew"
profiles = ["full"]
platforms = ["macos"]

[[entry]]
name = "karabiner"
kind = "tree"
src = "config/karabiner"
dest = "{XDG_CONFIG}/karabiner"
profiles = ["full"]
platforms = ["macos"]

[[entry]]
name = "kitty"
kind = "tree"
src = "config/kitty"
dest = "{XDG_CONFIG}/kitty"
profiles = ["full"]
platforms = ["macos"]

[[entry]]
name = "bin"
kind = "tree"
src = "bin"
dest = "{BIN}"
profiles = ["minimal", "standard", "full"]
platforms = ["all"]
```

- [ ] **Step 2: Write the reader core in `install/manifest.sh`**

```bash
#!/usr/bin/env bash

# Declarative manifest reader for dotfiles.
# Single source of source->destination truth. All TOML parsing is isolated in
# _manifest_awk; the rest of the codebase consumes the pipe-delimited records.

# Source shared library if not already loaded
if [[ -z "${dot_title:-}" ]]; then
  source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
fi

# Location of the declarative manifest (repo-relative by default)
MANIFEST_TOML="${MANIFEST_TOML:-${dot_root:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)}/install/manifest.toml}"

# Parse the constrained TOML subset into `name|kind|src|dest|profiles|platforms`
# records (one per entry). profiles/platforms are comma-joined with no spaces.
_manifest_awk() {
  awk '
    function flush() {
      if (have) printf "%s|%s|%s|%s|%s|%s\n", \
        e["name"], e["kind"], e["src"], e["dest"], e["profiles"], e["platforms"]
      have = 0; delete e
    }
    /^[[:space:]]*#/ { next }
    /^[[:space:]]*\[\[entry\]\]/ { flush(); have = 1; next }
    /^[[:space:]]*[a-z][a-z-]*[[:space:]]*=/ {
      key = $1
      eq = index($0, "=")
      val = substr($0, eq + 1)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", key)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", val)
      if (val ~ /^\[/) {
        gsub(/^\[|\]$/, "", val); gsub(/"/, "", val); gsub(/[[:space:]]+/, "", val)
      } else {
        gsub(/^"|"$/, "", val)
      }
      e[key] = val; have = 1; next
    }
    END { flush() }
  ' "$1"
}

# Print every manifest entry as name|kind|src|dest|profiles|platforms.
manifest_records() {
  [[ -f "$MANIFEST_TOML" ]] || { dot_error "Manifest not found: $MANIFEST_TOML"; return 1; }
  _manifest_awk "$MANIFEST_TOML"
}

# csv-membership test: does comma-list $2 contain exact token $1?
_manifest_csv_has() {
  local needle="$1" csv="$2" tok
  local IFS=,
  for tok in $csv; do [[ "$tok" == "$needle" ]] && return 0; done
  return 1
}

# Filter entries to a profile + OS. `all` profile matches every entry.
manifest_select() {
  local profile="$1" os="$2"
  local name kind src dest profiles platforms
  while IFS='|' read -r name kind src dest profiles platforms; do
    [[ -z "$name" ]] && continue
    _manifest_csv_has "all" "$platforms" || _manifest_csv_has "$os" "$platforms" || continue
    if [[ "$profile" != "all" ]]; then
      _manifest_csv_has "$profile" "$profiles" || continue
    fi
    printf '%s|%s|%s|%s|%s|%s\n' "$name" "$kind" "$src" "$dest" "$profiles" "$platforms"
  done < <(manifest_records)
}
```

- [ ] **Step 3: Write the failing tests in `tests/test-manifest.sh`**

```bash
#!/usr/bin/env bash
# Unit tests for the declarative manifest reader (install/manifest.sh).
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$REPO_ROOT" || exit 1

# shellcheck source=tests/lib.sh
source "$REPO_ROOT/tests/lib.sh"
export dot_root="$REPO_ROOT"
# shellcheck source=/dev/null
source "$REPO_ROOT/install/lib.sh"
# shellcheck source=/dev/null
source "$REPO_ROOT/install/manifest.sh"

echo "== manifest_records parsing =="
records="$(manifest_records)"
assert_contains "git entry parsed" "git|tree|config/git|{XDG_CONFIG}/git|minimal,standard,full|all" "$records"
assert_contains "zsh-env file entry parsed" "zsh-env|file|config/zsh/zshenv|{HOME}/.zshenv|minimal,standard,full|all" "$records"
assert_contains "lldb-init is macos only" "lldb-init|file|config/lldb/.lldbinit|{HOME}/.lldbinit|full|macos" "$records"

echo "== manifest_select profile filtering =="
min="$(manifest_select minimal macos)"
assert_contains "minimal includes git" $'\ngit|' $'\n'"$min"
assert_eq "minimal excludes nvim" "" "$(grep '^nvim|' <<<"$min" || true)"

std="$(manifest_select standard macos)"
assert_contains "standard includes nvim" "nvim|tree" "$std"
assert_eq "standard excludes clang-format" "" "$(grep '^clang-format|' <<<"$std" || true)"

echo "== manifest_select platform gating =="
full_ubuntu="$(manifest_select full ubuntu)"
assert_eq "full/ubuntu excludes kitty" "" "$(grep '^kitty|' <<<"$full_ubuntu" || true)"
assert_eq "full/ubuntu excludes lldb-init home file" "" "$(grep '^lldb-init|' <<<"$full_ubuntu" || true)"
assert_contains "full/ubuntu keeps lldb tree" "lldb|tree" "$full_ubuntu"
full_macos="$(manifest_select full macos)"
assert_contains "full/macos includes kitty" "kitty|tree" "$full_macos"
assert_contains "full/macos includes lldb-init" "lldb-init|file" "$full_macos"

echo "== all profile =="
all_macos="$(manifest_select all macos)"
assert_contains "all includes op" "op|tree" "$all_macos"
assert_contains "all includes nvim" "nvim|tree" "$all_macos"

echo
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
```

- [ ] **Step 4: Run the tests — expect failure first, then pass**

Run: `bash tests/test-manifest.sh`
Expected before Steps 1–2 exist: FAIL (source error / missing functions). After Steps 1–2: all `ok:`, `Results: N passed, 0 failed`.

- [ ] **Step 5: ShellCheck the new module**

Run: `shellcheck -S warning install/manifest.sh tests/test-manifest.sh`
Expected: no output (clean).

- [ ] **Step 6: Confirm the whole suite is still green**

Run: `make test`
Expected: existing suites pass and `test-manifest.sh` reports 0 failed.

- [ ] **Step 7: Commit**

```bash
git add install/manifest.toml install/manifest.sh tests/test-manifest.sh
git commit -m "$(cat <<'EOF'
manifest: add declarative source manifest and reader (parse/select)

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 2: Link expansion + component/home-dest/profile helpers

**Files:**
- Modify: `install/manifest.sh`
- Test: `tests/test-manifest.sh`

**Interfaces:**
- Consumes: `manifest_select`, `manifest_records`, `is_ignored`, `dot_root`, `XDG_CONFIG_HOME`, `HOME`.
- Produces:
  - `manifest_links <profile> <os>` → `src_file|dest_file` pairs (absolute), tree entries expanded (non-ignored, shadowed files removed), file entries emitted directly.
  - `manifest_component_links <name> <os>` → `src_file|dest_file` pairs for one component (its tree plus any file entry whose src is under that tree's src, or the standalone file entry named `<name>`), unfiltered by profile.
  - `manifest_components <profile> <os>` → component names (one per line) — tree names plus standalone file names (a file under a tree is not its own component).
  - `manifest_component_exists <name>` → 0 if `<name>` is a component whose src exists.
  - `manifest_home_dests <os>` → resolved dests of file entries that fall outside `{XDG_CONFIG}` and `{BIN}` (home-directory targets), for the given OS, across all profiles.
  - `manifest_component_of <src_repo_rel>` → the owning component name for a repo-relative file src (helper).

- [ ] **Step 1: Add resolution, shadowing, and link expansion to `install/manifest.sh`**

Append to `install/manifest.sh`:

```bash
# Resolve destination placeholders against the environment.
_manifest_resolve_dest() {
  local d="$1"
  d="${d//\{XDG_CONFIG\}/${XDG_CONFIG_HOME:-$HOME/.config}}"
  d="${d//\{HOME\}/$HOME}"
  d="${d//\{BIN\}/$HOME/.local/bin}"
  printf '%s' "$d"
}

# Absolute srcs of file-kind entries in the given selected record set (stdin).
# Used to shadow those files out of their containing tree.
_manifest_shadow_srcs() {
  local name kind src rest
  while IFS='|' read -r name kind src rest; do
    [[ "$kind" == "file" ]] || continue
    printf '%s\n' "${dot_root}/${src}"
  done
}

# Expand one entry to src|dest pairs. $4 is a newline list of shadowed abs srcs.
_manifest_emit() {
  local kind="$1" src="$2" dest="$3" shadow="$4"
  local abs_src="${dot_root}/${src}"
  local res_dest; res_dest="$(_manifest_resolve_dest "$dest")"

  if [[ "$kind" == "file" ]]; then
    [[ -f "$abs_src" ]] && printf '%s|%s\n' "$abs_src" "$res_dest"
    return 0
  fi

  local f rel
  while IFS= read -r f; do
    [[ -z "$f" ]] && continue
    is_ignored "$f" && continue
    if [[ -n "$shadow" ]] && grep -qxF "$f" <<<"$shadow"; then
      continue
    fi
    rel="${f#"$abs_src"/}"
    printf '%s|%s\n' "$f" "$res_dest/$rel"
  done < <(find "$abs_src" -type f 2>/dev/null | sort)
}

# THE single source of link truth: src|dest pairs for a profile + OS.
manifest_links() {
  local profile="$1" os="$2"
  local selected; selected="$(manifest_select "$profile" "$os")"
  local shadow; shadow="$(_manifest_shadow_srcs <<<"$selected")"
  local name kind src dest rest
  while IFS='|' read -r name kind src dest rest; do
    [[ -z "$name" ]] && continue
    _manifest_emit "$kind" "$src" "$dest" "$shadow"
  done <<<"$selected"
}
```

- [ ] **Step 2: Add component grouping + helper API to `install/manifest.sh`**

Append:

```bash
# Print the component that owns a repo-relative src: the name of a tree entry
# whose src is a path-prefix of $1, else $1's own entry name.
manifest_component_of() {
  local target="$1"
  local name kind src rest owner=""
  while IFS='|' read -r name kind src rest; do
    [[ -z "$name" ]] && continue
    if [[ "$kind" == "tree" && ( "$target" == "$src" || "$target" == "$src"/* ) ]]; then
      owner="$name"
    fi
  done < <(manifest_records)
  printf '%s' "$owner"
}

# Component names for a profile + OS. A file entry contained in a tree entry's
# src is folded into that tree's component (no standalone header).
manifest_components() {
  local profile="$1" os="$2"
  local name kind src rest
  while IFS='|' read -r name kind src rest; do
    [[ -z "$name" ]] && continue
    if [[ "$kind" == "file" ]]; then
      local owner; owner="$(manifest_component_of "$src")"
      [[ -n "$owner" ]] && continue   # folded into its tree component
    fi
    printf '%s\n' "$name"
  done < <(manifest_select "$profile" "$os")
}

# src|dest pairs for a single component (unfiltered by profile): the entry named
# <name> plus any file entry whose src is contained in that entry's tree src.
manifest_component_links() {
  local component="$1" os="$2"
  local name kind src dest rest
  local -a picked=()
  while IFS='|' read -r name kind src dest rest; do
    [[ -z "$name" ]] && continue
    if [[ "$name" == "$component" ]]; then
      picked+=("$name|$kind|$src|$dest")
    elif [[ "$kind" == "file" ]]; then
      local owner; owner="$(manifest_component_of "$src")"
      [[ "$owner" == "$component" ]] && picked+=("$name|$kind|$src|$dest")
    fi
  done < <(manifest_records)

  # OS gate the file-in-home entries so uninstall/status stay platform-correct
  local rec name2 kind2 src2 dest2 platforms
  local shadow=""
  # build shadow set from the picked file entries
  local p
  for p in "${picked[@]}"; do
    IFS='|' read -r name2 kind2 src2 dest2 <<<"$p"
    [[ "$kind2" == "file" ]] && shadow+="${dot_root}/${src2}"$'\n'
  done
  for p in "${picked[@]}"; do
    IFS='|' read -r name2 kind2 src2 dest2 <<<"$p"
    _manifest_emit "$kind2" "$src2" "$dest2" "$shadow"
  done
}

# 0 if <name> is a component (a top-level entry name that is not a file folded
# into another tree) whose source exists.
manifest_component_exists() {
  local component="$1"
  local name kind src rest
  while IFS='|' read -r name kind src rest; do
    [[ "$name" == "$component" ]] || continue
    [[ -e "${dot_root}/${src}" ]] && return 0
    return 1
  done < <(manifest_records)
  return 1
}

# Resolved dests of file entries that live outside {XDG_CONFIG} and {BIN}
# (i.e. home-directory targets like ~/.zshenv), OS-gated. Used by uninstall.
manifest_home_dests() {
  local os="$1"
  local name kind src dest profiles platforms res
  while IFS='|' read -r name kind src dest profiles platforms; do
    [[ -z "$name" ]] && continue
    [[ "$kind" == "file" ]] || continue
    [[ "$dest" == '{XDG_CONFIG}'* || "$dest" == '{BIN}'* ]] && continue
    _manifest_csv_has "all" "$platforms" || _manifest_csv_has "$os" "$platforms" || continue
    res="$(_manifest_resolve_dest "$dest")"
    printf '%s\n' "$res"
  done < <(manifest_records)
}
```

- [ ] **Step 3: Add link-expansion tests to `tests/test-manifest.sh`**

Insert before the final `echo`/`Results` block:

```bash
echo "== manifest_links tree expansion + shadowing =="
links_min="$(manifest_links minimal macos)"
assert_contains "zsh tree links .zshrc under XDG" \
  "$REPO_ROOT/config/zsh/.zshrc|${XDG_CONFIG_HOME:-$HOME/.config}/zsh/.zshrc" "$links_min"
assert_contains "zshenv is linked to HOME" \
  "$REPO_ROOT/config/zsh/zshenv|$HOME/.zshenv" "$links_min"
assert_eq "zshenv is shadowed out of the zsh tree" "" \
  "$(grep -F "config/zsh/zshenv|${XDG_CONFIG_HOME:-$HOME/.config}/zsh/zshenv" <<<"$links_min" || true)"
assert_contains "bin tree links a script into BIN" \
  "$REPO_ROOT/bin/mkx|$HOME/.local/bin/mkx" "$links_min"

echo "== manifest_links home files (full) =="
links_full="$(manifest_links full macos)"
assert_contains "clang-format links to home" \
  "$REPO_ROOT/config/clang-format|$HOME/.clang-format" "$links_full"
assert_contains "curl links to home" \
  "$REPO_ROOT/config/.curlrc|$HOME/.curlrc" "$links_full"
assert_contains "lldbinit.py links under XDG" \
  "$REPO_ROOT/config/lldb/lldbinit.py|${XDG_CONFIG_HOME:-$HOME/.config}/lldb/lldbinit.py" "$links_full"
assert_contains ".lldbinit links to home on macos" \
  "$REPO_ROOT/config/lldb/.lldbinit|$HOME/.lldbinit" "$links_full"
assert_eq ".lldbinit shadowed out of lldb tree on macos" "" \
  "$(grep -F "config/lldb/.lldbinit|${XDG_CONFIG_HOME:-$HOME/.config}/lldb/.lldbinit" <<<"$links_full" || true)"

echo "== lldb on ubuntu keeps XDG .lldbinit (not shadowed) =="
links_full_ubuntu="$(manifest_links full ubuntu)"
assert_contains "ubuntu links .lldbinit under XDG (no home file selected)" \
  "$REPO_ROOT/config/lldb/.lldbinit|${XDG_CONFIG_HOME:-$HOME/.config}/lldb/.lldbinit" "$links_full_ubuntu"

echo "== components + component_links + exists + home_dests =="
comps="$(manifest_components full macos)"
assert_contains "components include zsh" $'\nzsh\n' $'\n'"$comps"$'\n'
assert_eq "zsh-env is not its own component" "" "$(grep -x 'zsh-env' <<<"$comps" || true)"
zsh_links="$(manifest_component_links zsh macos)"
assert_contains "component zsh includes tree file" \
  "$REPO_ROOT/config/zsh/.zshrc|${XDG_CONFIG_HOME:-$HOME/.config}/zsh/.zshrc" "$zsh_links"
assert_contains "component zsh includes home zshenv" \
  "$REPO_ROOT/config/zsh/zshenv|$HOME/.zshenv" "$zsh_links"
assert_eq "manifest_component_exists nvim" "0" "$(manifest_component_exists nvim; echo $?)"
assert_eq "manifest_component_exists bogus" "1" "$(manifest_component_exists bogus; echo $?)"
home_macos="$(manifest_home_dests macos)"
assert_contains "home_dests has zshenv" "$HOME/.zshenv" "$home_macos"
assert_contains "home_dests has clang-format" "$HOME/.clang-format" "$home_macos"
assert_contains "home_dests has curl" "$HOME/.curlrc" "$home_macos"
assert_contains "home_dests has lldbinit on macos" "$HOME/.lldbinit" "$home_macos"
assert_eq "home_dests omits lldbinit on ubuntu" "" \
  "$(grep -F "$HOME/.lldbinit" <<<"$(manifest_home_dests ubuntu)" || true)"
```

- [ ] **Step 4: Run tests — expect the new assertions to pass**

Run: `bash tests/test-manifest.sh`
Expected: `Results: N passed, 0 failed`.

- [ ] **Step 5: ShellCheck**

Run: `shellcheck -S warning install/manifest.sh tests/test-manifest.sh`
Expected: clean.

- [ ] **Step 6: Full suite green**

Run: `make test`
Expected: all suites pass.

- [ ] **Step 7: Commit**

```bash
git add install/manifest.sh tests/test-manifest.sh
git commit -m "$(cat <<'EOF'
manifest: add link expansion, component grouping, and home-dest helpers

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 3: Rewire bootstrap linking onto the manifest

**Files:**
- Modify: `bootstrap.sh` (source manifest; rewrite `link_configs`; fold in `link_binaries`; remove `--synced`, `--config-dest`, `--bin-dest`)
- Test: `tests/test-bootstrap.sh` (existing behavior assertions must stay green; no edits required in this task)

**Interfaces:**
- Consumes: `manifest_links <profile> <os>`, `manifest_component_links <name> <os>`, `manifest_component_exists <name>`, `create_symlink`, `create_directory`.
- Produces: `bootstrap.sh --profile <p>` and `--sync --config <name>` link exactly the manifest's pairs and write the installed manifest via `create_symlink`.

- [ ] **Step 1: Source the manifest reader in `bootstrap.sh`**

In `bootstrap.sh`, after `source "$SCRIPT_DIR/install/symlinks.sh"` (around line 55), add:

```bash
source "$SCRIPT_DIR/install/manifest.sh"
```

Leave the existing `source .../profiles.sh` line in place for now (Task 6 removes it).

- [ ] **Step 2: Replace `link_configs` (bootstrap.sh:250-303) with a manifest-driven version**

```bash
# Link configuration files from the declarative manifest.
link_configs() {
  dot_title "Linking configuration files"

  if [[ "$VERBOSE" == "true" ]]; then
    dot_info "Profile: $PROFILE ($(get_profile_description "$PROFILE"))"
    dot_info "OS: $OS_TYPE"
  fi

  local links
  if [[ -n "$SYNC_CONFIG" ]]; then
    if ! manifest_component_exists "$SYNC_CONFIG"; then
      dot_error "Config not found: $SYNC_CONFIG"
      exit 1
    fi
    dot_info "Processing $SYNC_CONFIG configuration..."
    links="$(manifest_component_links "$SYNC_CONFIG" "$OS_TYPE")"
  else
    links="$(manifest_links "$PROFILE" "$OS_TYPE")"
  fi

  local source dest
  while IFS='|' read -r source dest; do
    [[ -z "$source" ]] && continue
    create_symlink "$source" "$dest"
  done <<<"$links"

  dot_success "Configuration files linked"
}
```

Note: the "Processing <config>..." per-component line is preserved only for single-config sync; the full profile no longer prints a line per component (it was cosmetic). `tests/test-bootstrap.sh` asserts "Processing git configuration" for a **full-profile** dry run at lines 71-73 — that assertion is updated in Task 6. To keep Task 3 green, add a per-component banner: replace the `else` branch above with a loop that still announces each component. Use this instead for the whole function body of the else branch:

```bash
  else
    local comp
    while IFS= read -r comp; do
      [[ -z "$comp" ]] && continue
      dot_info "Processing $comp configuration..."
    done < <(manifest_components "$PROFILE" "$OS_TYPE")
    links="$(manifest_links "$PROFILE" "$OS_TYPE")"
  fi
```

This preserves the "Processing <config> configuration..." lines the current tests assert, so Task 3 keeps `make test` green with no test edits.

- [ ] **Step 3: Fold binaries into the manifest — neutralize `link_binaries`**

`bin` is now a manifest entry, so `link_configs` already links it. Replace the body of `link_binaries` (bootstrap.sh:306-322) so it is a no-op that still creates the dir (kept for call-site compatibility until Task 6 removes the calls):

```bash
# Binaries are linked via the manifest `bin` entry in link_configs; this
# remains only to ensure the destination directory exists.
link_binaries() {
  create_directory "$BIN_DEST"
}
```

- [ ] **Step 4: Remove `--synced`, `--config-dest`, `--bin-dest` from arg parsing**

In `parse_args` (bootstrap.sh:131-201) delete the `-c | --config-dest)`, `-b | --bin-dest)`, and `--synced)` cases entirely. Delete the `declare -g SYNC_SYNCED=false` line (bootstrap.sh:47) and the `--synced` line in `usage()` (bootstrap.sh:71) plus the `-c`/`-b` lines in `usage()` (bootstrap.sh:72-73). In `main`, remove `SYNC_SYNCED` from the `export` list (bootstrap.sh:418). In the sync-mode block (bootstrap.sh:446-457) remove the `SYNC_SYNCED` branch so binaries always link unless a single `--config` is requested:

```bash
    # Link binaries (skip only when syncing one specific config)
    if [[ -z "$SYNC_CONFIG" ]]; then
      link_binaries
    fi

    if [[ -z "$SYNC_CONFIG" && -z "$DRY_RUN" ]]; then
      printf '%s\n' "$PROFILE" >"$PROFILE_FILE"
    fi
```

- [ ] **Step 5: Delete the `--synced`/`get_synced_configs` fallback and dest-flag defaults**

`CONFIG_DEST`/`BIN_DEST` still resolve to the XDG/HOME defaults in `main` (bootstrap.sh:410-411) — keep those; they are now the only source. Confirm no remaining reference to `SYNC_SYNCED`, `get_synced_configs`, `has_synced_binaries`, `CONFIG_DEST` from a flag, or `SYNC_SYNCED` export:

Run: `grep -nE 'SYNC_SYNCED|--synced|--config-dest|--bin-dest|get_synced_configs|has_synced_binaries' bootstrap.sh`
Expected: no output.

- [ ] **Step 6: Run bootstrap regression + manifest tests**

Run: `bash tests/test-bootstrap.sh && bash tests/test-manifest.sh`
Expected: both `Results: N passed, 0 failed`. In particular the "install + uninstall round trip" and "stored profile sync" sections must still pass (tmux/zshenv/bin links created, nvim linked after profile switch).

- [ ] **Step 7: ShellCheck + full suite**

Run: `shellcheck -S warning bootstrap.sh && make test`
Expected: clean; all suites pass.

- [ ] **Step 8: Commit**

```bash
git add bootstrap.sh
git commit -m "$(cat <<'EOF'
bootstrap: drive linking from the manifest; drop --synced and dest flags

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 4: Rewire `dotfiles status` onto the manifest

**Files:**
- Modify: `bin/dotfiles` (source manifest; rewrite `cmd_status`)

**Interfaces:**
- Consumes: `manifest_components <profile> <os>`, `manifest_component_links <name> <os>`, `manifest_component_exists <name>`, `check_symlink`, `validate_profile`, `get_stored_profile`.
- Produces: profile-aware status that iterates manifest components; exit code 1 when any expected link is broken/missing, 0 otherwise (preserving STATUS-01).

- [ ] **Step 1: Source the manifest reader in `bin/dotfiles`**

After `source "$DOTFILES_ROOT/install/symlinks.sh"` (bin/dotfiles:38), add:

```bash
source "$DOTFILES_ROOT/install/manifest.sh"
```

Keep the existing `source .../profiles.sh` line for now (Task 6 removes it).

- [ ] **Step 2: Replace `cmd_status` (bin/dotfiles:161-277) with a manifest-driven version**

```bash
# Command: status - Show symlink health
cmd_status() {
  local show_details=true
  for arg in "$@"; do
    case "$arg" in
      --summary | -s) show_details=false ;;
    esac
  done

  if [[ "$show_details" == "true" ]]; then
    dot_title "Dotfiles Symlink Status"
  fi

  local profile
  profile=$(get_stored_profile)
  if ! validate_profile "$profile"; then
    dot_error "Stored profile is invalid: $profile"
    return 2
  fi

  if [[ "$show_details" == "true" ]]; then
    dot_info "Checking configuration symlinks..."
    echo
  fi

  local total_ok=0 total_broken=0 total_missing=0
  local component

  while IFS= read -r component; do
    [[ -z "$component" ]] && continue
    if ! manifest_component_exists "$component"; then
      dot_error "Invalid manifest component: $component"
      return 2
    fi

    if [[ "$show_details" == "true" ]]; then
      printf "%b%s:%b\n" "$COLOR_HEADER" "$component" "$COLOR_RESET"
    fi

    local src dest
    while IFS='|' read -r src dest; do
      [[ -z "$src" ]] && continue
      if [[ "$show_details" == "true" ]]; then
        check_symlink "$src" "$dest" true
      else
        check_symlink "$src" "$dest" false >/dev/null 2>&1
      fi
      local status=$?
      case $status in
        0) ((total_ok++)) || true ;;
        1) ((total_broken++)) || true ;;
        2) ((total_missing++)) || true ;;
      esac
    done < <(manifest_component_links "$component" "$OS_TYPE")

    [[ "$show_details" == "true" ]] && echo
  done < <(manifest_components "$profile" "$OS_TYPE")

  dot_title "Summary"
  print_status "ok" "Correct symlinks: $total_ok"
  print_status "broken" "Broken symlinks: $total_broken"
  print_status "missing" "Missing symlinks: $total_missing"

  if [[ $total_broken -gt 0 ]] || [[ $total_missing -gt 0 ]]; then
    echo
    dot_info "Run 'dotfiles sync' to fix issues"
    return 1
  fi
  return 0
}
```

Note: `manifest_component_links` is OS-gated for its file entries, so on Ubuntu a `full`-profile status does not report `~/.lldbinit` as missing. The separate `bin/` scan is gone — `bin` is a component and shows under its own `bin:` header.

- [ ] **Step 3: Verify status behavior in an isolated HOME (manual driver test)**

Run:

```bash
tmp="$(mktemp -d)"
HOME="$tmp" ./bootstrap.sh --sync --profile standard >/dev/null 2>&1
HOME="$tmp" ./bin/dotfiles status --summary; echo "rc=$?"
rm "$tmp/.config/nvim/init.lua"
HOME="$tmp" ./bin/dotfiles status --summary; echo "rc=$?"
rm -rf "$tmp"
```

Expected: first `rc=0` (all standard links healthy); after removing a linked file, `rc=1` (missing detected).

- [ ] **Step 4: Regression + shellcheck**

Run: `bash tests/test-bootstrap.sh && shellcheck -S warning bin/dotfiles && make test`
Expected: all green. (`test-bootstrap.sh` "profile-aware healthy status exits zero" and "status fails for a missing expected link" still pass.)

- [ ] **Step 5: Commit**

```bash
git add bin/dotfiles
git commit -m "$(cat <<'EOF'
dotfiles: derive status from the manifest components

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 5: Rewire uninstall home-file targets onto the manifest

**Files:**
- Modify: `bin/dotfiles` (`cmd_uninstall`: home-file targets from `manifest_home_dests`; scoped uninstall via `manifest_component_links`)

**Interfaces:**
- Consumes: `manifest_home_dests <os>`, `manifest_component_links <name> <os>`, `manifest_component_exists <name>`, `is_owned_symlink`, `find_owned_symlinks`, `uninstall_symlink`.
- Produces: full uninstall removes owned `~/.config` + `~/.local/bin` links **plus every manifest home-file dest** (now including `~/.clang-format` and `~/.curlrc`); scoped uninstall removes the named component's links including its home file.

- [ ] **Step 1: Replace the full-uninstall home-file loop (bin/dotfiles:384-386)**

Current:

```bash
    for link in "$HOME/.zshenv" "$HOME/.lldbinit"; do
      is_owned_symlink "$link" "$DOTFILES_ROOT" && targets+=("$link")
    done
```

New:

```bash
    while IFS= read -r link; do
      [[ -z "$link" ]] && continue
      is_owned_symlink "$link" "$DOTFILES_ROOT" && targets+=("$link")
    done < <(manifest_home_dests "$OS_TYPE")
```

- [ ] **Step 2: Replace the scoped-uninstall config branch (bin/dotfiles:388-401)**

Current scoped branch derives targets from `find_owned_symlinks "$HOME/.config/$config"` plus hardcoded zsh/lldb home-file special cases. Replace the per-config body with manifest-derived dests, keeping the `bin` special case:

```bash
    local config
    for config in "${configs[@]}"; do
      if [[ "$config" == "bin" ]]; then
        while IFS= read -r link; do targets+=("$link"); done \
          < <(find_owned_symlinks "$HOME/.local/bin" "$DOTFILES_ROOT/bin")
        continue
      fi
      if ! manifest_component_exists "$config"; then
        dot_error "Unknown config: $config"
        exit 1
      fi
      local src dest
      while IFS='|' read -r src dest; do
        [[ -z "$dest" ]] && continue
        is_owned_symlink "$dest" "$DOTFILES_ROOT" && targets+=("$dest")
      done < <(manifest_component_links "$config" "$OS_TYPE")
    done
```

- [ ] **Step 3: Update the scoped-config argument validation (bin/dotfiles:348-356)**

The arg parser currently accepts a config when `[[ -d "$CONFIG_DIR/$1" || "$1" == "bin" ]]`. Change it to accept any manifest component or `bin`:

```bash
      *)
        if [[ "$1" == "bin" ]] || manifest_component_exists "$1"; then
          configs+=("$1")
          shift
        else
          dot_error "Unknown config: $1"
          exit 1
        fi
        ;;
```

- [ ] **Step 4: Full-profile round-trip driver test (macOS-relevant home files)**

Run:

```bash
tmp="$(mktemp -d)"
HOME="$tmp" ./bootstrap.sh --sync --profile full >/dev/null 2>&1
echo "clang linked: $([[ -L "$tmp/.clang-format" ]] && echo yes || echo no)"
echo "curl linked:  $([[ -L "$tmp/.curlrc" ]] && echo yes || echo no)"
HOME="$tmp" ./bin/dotfiles uninstall --yes >/dev/null 2>&1
echo "clang after uninstall: $([[ -L "$tmp/.clang-format" ]] && echo yes || echo no)"
echo "curl after uninstall:  $([[ -L "$tmp/.curlrc" ]] && echo yes || echo no)"
rm -rf "$tmp"
```

Expected on a machine where those config sources exist: `linked: yes` for both after install (all-platform entries), and `no` after uninstall — proving the manifest-derived home dests are removed (the pre-manifest code left `~/.clang-format` and `~/.curlrc` behind).

- [ ] **Step 5: Scoped uninstall driver test (zsh includes ~/.zshenv)**

Run:

```bash
tmp="$(mktemp -d)"
HOME="$tmp" ./bootstrap.sh --sync --profile minimal >/dev/null 2>&1
HOME="$tmp" ./bin/dotfiles uninstall zsh --yes >/dev/null 2>&1
echo "zshenv removed: $([[ -L "$tmp/.zshenv" ]] && echo no || echo yes)"
echo "tmux kept:      $([[ -L "$tmp/.config/tmux/tmux.conf" ]] && echo yes || echo no)"
rm -rf "$tmp"
```

Expected: `zshenv removed: yes` and `tmux kept: yes` (scoped uninstall of `zsh` removes its home file but not other components).

- [ ] **Step 6: Regression + shellcheck + suite**

Run: `bash tests/test-uninstall.sh && bash tests/test-bootstrap.sh && shellcheck -S warning bin/dotfiles && make test`
Expected: all green.

- [ ] **Step 7: Commit**

```bash
git add bin/dotfiles
git commit -m "$(cat <<'EOF'
dotfiles: derive uninstall home files and scoped targets from the manifest

Also removes ~/.clang-format and ~/.curlrc on full uninstall (previously
left behind).

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 6: Cutover — delete `profiles.sh` and dead `symlinks.sh` functions; update tests

**Files:**
- Delete: `install/profiles.sh`
- Modify: `install/manifest.sh` (add `validate_profile`, `get_profile_description`)
- Modify: `install/symlinks.sh` (remove `get_config_symlinks`, `get_synced_configs`, `has_synced_binaries`, `check_symlink_health`)
- Modify: `bootstrap.sh`, `bin/dotfiles` (drop `source .../profiles.sh`)
- Modify: `tests/test-bootstrap.sh` (replace removed-symbol tests with manifest equivalents)

**Interfaces:**
- Consumes: nothing new.
- Produces: `validate_profile <p>` returns 0 for `minimal|standard|full|all` only; `get_profile_description <p>` unchanged text; `custom` rejected everywhere.

- [ ] **Step 1: Move `validate_profile` (custom removed) and `get_profile_description` into `install/manifest.sh`**

Append to `install/manifest.sh`:

```bash
# Validate a profile name. `custom` is no longer supported.
validate_profile() {
  case "$1" in
    minimal | standard | full | all) return 0 ;;
    *)
      dot_error "Invalid profile: $1"
      dot_error "Valid profiles: minimal, standard, full, all"
      return 1
      ;;
  esac
}

get_profile_description() {
  case "$1" in
    minimal) echo "Essential configs only (git, zsh, tmux)" ;;
    standard) echo "Common development tools (minimal + nvim, bat, python)" ;;
    full) echo "Everything including GUI apps" ;;
    all) echo "All available configs in the manifest" ;;
    *) echo "Unknown profile" ;;
  esac
}
```

- [ ] **Step 2: Delete `install/profiles.sh` and drop its `source` lines**

```bash
git rm install/profiles.sh
```

In `bootstrap.sh` remove the line `source "$SCRIPT_DIR/install/profiles.sh"` (was ~line 56). In `bin/dotfiles` remove the line `source "$DOTFILES_ROOT/install/profiles.sh"` (was ~line 39). Ensure `source .../manifest.sh` is present in both (added in Tasks 3–4).

- [ ] **Step 3: Remove dead functions from `install/symlinks.sh`**

Delete these entire functions from `install/symlinks.sh`: `get_config_symlinks` (406-458), `check_symlink_health` (461-499), `get_synced_configs` (335-385), `has_synced_binaries` (388-403). Also delete the stale comment at 208-210 that references `get_synced_configs`. Keep everything else (create/check/clean/uninstall/backup/manifest helpers).

Run: `grep -nE 'get_config_symlinks|get_synced_configs|has_synced_binaries|check_symlink_health' bootstrap.sh bin/dotfiles install/symlinks.sh install/manifest.sh`
Expected: no output.

- [ ] **Step 4: Update `tests/test-bootstrap.sh` — swap the profiles.sh block for manifest checks**

Replace lines 15-67 (the `get_config_list`, `config_component_exists`, and `get_config_symlinks` sections, and the `source .../profiles.sh` line) with:

```bash
echo "== manifest profile selection =="
# shellcheck source=/dev/null
source "$REPO_ROOT/install/lib.sh"
export dot_root="$REPO_ROOT"
# shellcheck source=/dev/null
source "$REPO_ROOT/install/symlinks.sh"
# shellcheck source=/dev/null
source "$REPO_ROOT/install/manifest.sh"

assert_contains "minimal selects git" "git|tree" "$(manifest_select minimal macos)"
assert_eq "minimal excludes nvim" "" "$(manifest_select minimal macos | grep '^nvim|' || true)"
assert_contains "standard adds nvim" "nvim|tree" "$(manifest_select standard macos)"

full_macos_links="$(manifest_links full macos)"
assert_contains "full/macos links kitty" "/config/kitty/" "$full_macos_links"
assert_contains "full maps curl to home" "$REPO_ROOT/config/.curlrc|$HOME/.curlrc" "$full_macos_links"
assert_contains "full maps clang-format to home" "$REPO_ROOT/config/clang-format|$HOME/.clang-format" "$full_macos_links"

assert_eq "full/ubuntu has no macOS extras" "" \
  "$(manifest_links full ubuntu | grep -E '/config/(karabiner|kitty|homebrew)/' || true)"

if validate_profile bogus >/dev/null 2>&1; then
  FAIL=$((FAIL + 1)); echo "  FAIL: unknown profile should be rejected"
else
  PASS=$((PASS + 1)); echo "  ok: unknown profile rejected"
fi
if validate_profile custom >/dev/null 2>&1; then
  FAIL=$((FAIL + 1)); echo "  FAIL: custom profile should be rejected"
else
  PASS=$((PASS + 1)); echo "  ok: custom profile rejected"
fi
```

- [ ] **Step 5: Update the `all` profile exclusion test (test-bootstrap.sh:123-130)**

Replace with:

```bash
echo "== all profile exclusions =="
all_comps="$(manifest_components all macos)"
for excluded in macos ubuntu defaults security; do
  assert_eq "all profile excludes $excluded" "" "$(grep -x "$excluded" <<<"$all_comps" || true)"
done
assert_contains "all profile still includes real configs" "nvim" "$all_comps"
```

- [ ] **Step 6: Update the bash-version-guard comment (test-bootstrap.sh:133-134)**

Change the comment referencing `profiles.sh` to `manifest.sh` (the guard still requires bash 4 for `declare -gA` used across the shared libs). No behavior change.

- [ ] **Step 7: Run everything**

Run: `make test && shellcheck -S warning bootstrap.sh bin/dotfiles install/*.sh tests/*.sh`
Expected: all suites pass; shellcheck clean. Confirm `install/profiles.sh` is gone: `test ! -e install/profiles.sh && echo removed`.

- [ ] **Step 8: Commit**

```bash
git add -A
git commit -m "$(cat <<'EOF'
manifest: retire profiles.sh and dead symlink derivations; reject custom

validate_profile/get_profile_description move into manifest.sh; the
interactive subsystem, get_config_list, get_config_symlinks,
get_synced_configs, has_synced_binaries, and check_symlink_health are
removed. Tests updated to the manifest API.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 7: Remove empty scaffold trees; verify hook lifecycle inputs

**Files:**
- Delete: `config/defaults`, `config/security`, `config/ubuntu` (if empty)
- Modify: `tests/test-manifest.sh` (add a hook-input assertion)
- Verify: `.githooks/post-checkout`, `.githooks/post-merge`

**Interfaces:** none new.

- [ ] **Step 1: Confirm the scaffold trees are empty, then remove them**

Run:

```bash
for d in config/defaults config/security config/ubuntu; do
  echo "$d: $(find "$d" -type f 2>/dev/null | wc -l | tr -d ' ') files"
done
```

Expected: `0 files` each. If any has files, stop and report (do not delete). If all zero:

```bash
git rm -r --ignore-unmatch config/defaults config/security config/ubuntu 2>/dev/null
rmdir config/defaults config/security config/ubuntu 2>/dev/null || true
```

(Empty dirs are untracked by git; `rmdir` clears any that remain on disk.)

- [ ] **Step 2: Verify the hooks already cover the manifest lifecycle inputs**

Run: `grep -nE "config/\|install/\|bin/\|bootstrap" .githooks/post-checkout .githooks/post-merge`
Expected: both hooks contain the pattern `^(config/|install/|bin/|bootstrap\.sh$)`. Since `install/manifest.toml` and `install/manifest.sh` live under `install/`, a change to either already triggers sync — PROFILE-03 is satisfied. No hook edit needed.

- [ ] **Step 3: Add a regression assertion that the manifest path is a hook trigger**

Append to `tests/test-manifest.sh` before the `Results` block:

```bash
echo "== hook change-detection covers the manifest =="
hook_pattern='^(config/|install/|bin/|bootstrap\.sh$)'
assert_eq "manifest.toml matches the hook trigger" "install/manifest.toml" \
  "$(printf 'install/manifest.toml\n' | grep -E "$hook_pattern")"
assert_eq "post-checkout uses the lifecycle pattern" "yes" \
  "$([[ "$(cat "$REPO_ROOT/.githooks/post-checkout")" == *'install/'* ]] && echo yes || echo no)"
```

- [ ] **Step 4: Run tests + shellcheck**

Run: `make test && shellcheck -S warning .githooks/post-checkout .githooks/post-merge`
Expected: green; shellcheck clean.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "$(cat <<'EOF'
config: remove empty scaffold trees; assert hooks cover the manifest

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 8: Documentation and review reconciliation

**Files:**
- Modify: `README.md`
- Modify: `CLAUDE.md`
- Modify: `docs/REVIEW-2026-07-14.md`

**Interfaces:** none.

- [ ] **Step 1: Update `CLAUDE.md` configuration-management section**

In the "Configuration Management" and "Adding New Configurations" sections, replace the "bootstrap script automatically creates symlinks for new files in `config/`" guidance with: new components are declared in `install/manifest.toml` (name/kind/src/dest/profiles/platforms); `bootstrap.sh`, `dotfiles status`, and `dotfiles uninstall` all derive their file set from it. Note that `~/.config/.dotfiles-manifest` remains the runtime record.

- [ ] **Step 2: Update `README.md`**

- Remove any `--config-dest` / `--bin-dest` documentation.
- Remove the `custom` profile from profile descriptions; list `minimal | standard | full | all`.
- Add a short "Adding a component" note pointing at `install/manifest.toml`.
- Note `op` (1Password CLI config) is part of the `full` profile.

Run to find the spots: `grep -nE 'config-dest|bin-dest|custom' README.md`
Expected after edit: no stale `--config-dest`/`--bin-dest`/`custom` references remain.

- [ ] **Step 3: Mark the addressed findings Resolved in `docs/REVIEW-2026-07-14.md`**

For each of DEST-01, PROFILE-04, PROFILE-03, SCAFFOLD-01, and the Phase 1 item "Introduce one declarative source/destination/profile/platform manifest", add a `Resolved: 2026-07-14 by <commit>` line in the existing style, and tick the Phase 1.1 checklist entry. Use the final squash/merge commit hash if known, otherwise the Task 6 commit hash. Example for DEST-01:

```markdown
### DEST-01 — Custom destination flags are only partially honored — Resolved

- Original severity/status: **Medium / Confirmed by static trace**
- Resolved: 2026-07-14 by removing --config-dest/--bin-dest; the declarative
  manifest resolves XDG/HOME destinations for every lifecycle command.
```

Also update Phase 1 item 1 in "Recommended remediation order" to strike-through/Resolved, matching how items 2–4 there are already marked.

- [ ] **Step 4: Sanity check docs for the removed surface**

Run: `grep -nE 'config-dest|bin-dest|--synced|profiles\.sh|custom profile' README.md CLAUDE.md`
Expected: no stale references (matches inside `docs/REVIEW-*.md` history are fine).

- [ ] **Step 5: Commit**

```bash
git add README.md CLAUDE.md docs/REVIEW-2026-07-14.md
git commit -m "$(cat <<'EOF'
docs: document the declarative manifest; mark Phase 1 findings resolved

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 9: Whole-branch verification

**Files:** none (verification only).

- [ ] **Step 1: Full test suite on this platform**

Run: `make test`
Expected: `Results: ... 0 failed` for every `tests/test-*.sh`; overall exit 0.

- [ ] **Step 2: ShellCheck the gated set**

Run: `shellcheck -S warning bootstrap.sh install/*.sh bin/dotfiles tests/*.sh .githooks/setup.sh .githooks/post-merge .githooks/post-checkout`
Expected: clean.

- [ ] **Step 3: End-to-end profile matrix in isolated HOMEs**

Run:

```bash
for p in minimal standard full; do
  tmp="$(mktemp -d)"
  HOME="$tmp" ./bootstrap.sh --sync --profile "$p" >/dev/null 2>&1
  HOME="$tmp" ./bin/dotfiles status --summary >/dev/null 2>&1
  echo "$p status rc=$?"
  HOME="$tmp" ./bin/dotfiles uninstall --yes >/dev/null 2>&1
  left="$(find "$tmp" -type l 2>/dev/null | wc -l | tr -d ' ')"
  echo "$p links left after uninstall=$left"
  rm -rf "$tmp"
done
```

Expected: each `status rc=0` and `links left after uninstall=0`.

- [ ] **Step 4: Confirm no dangling references to removed surface**

Run: `grep -rnE 'profiles\.sh|get_config_list|get_config_symlinks|get_synced_configs|has_synced_binaries|--config-dest|--bin-dest|--synced' bootstrap.sh bin/dotfiles install Makefile .githooks`
Expected: no output.

- [ ] **Step 5: Request code review**

Use `superpowers:requesting-code-review` for a whole-branch review, then `superpowers:finishing-a-development-branch` to integrate.

---

## Self-Review

**Spec coverage:**
- Manifest format (TOML subset + isolated awk) → Task 1.
- Entry set / profiles / platforms / home-files / shadowing → Tasks 1–2.
- `manifest_links` as the single derivation for link/status/uninstall → Tasks 2–5.
- DEST-01 (remove flags) → Task 3 (Steps 4–5).
- PROFILE-04 (delete interactive, reject `custom`) → Task 6.
- `--synced` removal → Task 3.
- `op` → full → Task 1 (manifest.toml).
- clean unchanged (installed-manifest projection) → no task needed; verified in Task 9 Step 3.
- Installed manifest unchanged, written by `create_symlink` → preserved (Tasks 3, 9).
- PROFILE-03 (hook lifecycle inputs) → Task 7 (already satisfied by `install/`; asserted).
- SCAFFOLD-01 → Task 7.
- Tests (new manifest + lifecycle coverage; update test-bootstrap) → Tasks 1, 2, 6, 7 + driver tests in 3–5.
- Docs + review Resolved marks → Task 8.
- Migration/back-compat (idempotent reconcile; legacy `custom` errors) → covered by `validate_profile` (Task 6) and preserved installed-manifest format (Task 3); no migration step required.

**Placeholder scan:** No TBD/TODO/"handle edge cases"/"similar to Task N" — every code step shows full code.

**Type/name consistency:** API names are consistent across tasks — `manifest_records`, `manifest_select`, `manifest_links`, `manifest_component_links`, `manifest_components`, `manifest_component_exists`, `manifest_home_dests`, `manifest_component_of`, `_manifest_resolve_dest`, `_manifest_emit`, `_manifest_shadow_srcs`, `_manifest_csv_has`, `_manifest_awk`, `validate_profile`, `get_profile_description`. Placeholder tokens `{XDG_CONFIG}`/`{HOME}`/`{BIN}` are used identically in the manifest and `_manifest_resolve_dest`.
