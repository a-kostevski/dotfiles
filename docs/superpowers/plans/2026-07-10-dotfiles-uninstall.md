# `dotfiles uninstall` Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a `dotfiles uninstall [config...]` command that removes repo-owned symlinks via filesystem scan, restores the newest backups by default, prunes empty dirs, and finally makes the manifest useful (deduped on write, pruned/deleted on uninstall).

**Architecture:** Core helpers go in `install/symlinks.sh` next to their siblings (`create_symlink`, `clean_broken_symlinks`); `cmd_uninstall` in `bin/dotfiles` stays a thin arg-parse/loop/summary layer, mirroring `cmd_sync`. Discovery is a filesystem scan — a symlink is "ours" iff its `readlink` target lies under `$DOTFILES_ROOT/`. The manifest is never trusted for discovery, only cleaned up.

**Tech Stack:** bash 4+ (repo already gates on this), GNU/BSD-portable `find`/`awk`, existing `install/lib.sh` helpers (`dry_run`, `print_status`, `dot_info`/`dot_warning`/`dot_error`/`dot_success`, `dot_title`). Tests follow `tests/test-bootstrap.sh` conventions (plain bash, `assert_eq`/`assert_contains`, PASS/FAIL counters).

**Spec:** `docs/superpowers/specs/2026-07-10-dotfiles-uninstall-design.md`

## Global Constraints

- bash 4+ only; both entry points already guard `BASH_VERSINFO[0] < 4`.
- `shellcheck -S warning bootstrap.sh install/*.sh bin/dotfiles tests/*.sh` must stay clean (CI gates at warning; see `Makefile:184`).
- Every mutating action goes through the `dry_run` helper from `install/lib.sh` (prints `[DRY-RUN] cmd...` when `DRY_RUN` is non-empty, executes otherwise).
- Manifest writes are skipped entirely under `DRY_RUN` (matches `create_symlink:93`).
- Never remove `~/.config` itself or `~/.local/bin`.
- Never touch a real file or a foreign symlink (target outside the repo).
- Style: 2-space indent in `bin/dotfiles`, 4-space in `install/symlinks.sh` (match each file's existing indent); `local x; x=$(...)` split to avoid SC2155; counters updated in the main shell via process substitution (see the comments at `bin/dotfiles:185` and `install/symlinks.sh:139`).
- Backup naming produced by `unique_backup_path`: `<dest>.backup.YYYYMMDD_HHMMSS` plus optional `.N` collision suffix. Newest is chosen by **mtime** (`-nt`), not lexically.
- Run tests from repo root: `bash tests/test-uninstall.sh` (and `make test` at the end).

---

### Task 1: Test harness + ownership scan (`find_owned_symlinks`, `is_owned_symlink`)

**Files:**
- Create: `tests/test-uninstall.sh`
- Modify: `Makefile` (test target, lines 116-121)
- Modify: `install/symlinks.sh` (append new functions after `clean_broken_symlinks`, ~line 179)

**Interfaces:**
- Produces: `is_owned_symlink <link> <owner_root>` — rc 0 iff `<link>` is a symlink whose target starts with `<owner_root>/`.
- Produces: `find_owned_symlinks <dir> <owner_root>` — prints one owned-symlink path per line, unbounded depth, rc 0 even if dir missing.
- Produces: `tests/test-uninstall.sh` with `assert_eq`/`assert_contains` helpers — later tasks append test sections to this file.

- [ ] **Step 1: Write the failing test file**

Create `tests/test-uninstall.sh`:

```bash
#!/usr/bin/env bash
# Regression tests for the uninstall machinery.
# Run via `make test` or directly: bash tests/test-uninstall.sh

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT" || exit 1

PASS=0
FAIL=0

assert_eq() {
  local desc="$1" expected="$2" actual="$3"
  if [[ "$expected" == "$actual" ]]; then
    PASS=$((PASS + 1))
    echo "  ok: $desc"
  else
    FAIL=$((FAIL + 1))
    echo "  FAIL: $desc"
    echo "    expected: $(printf '%q' "$expected")"
    echo "    actual:   $(printf '%q' "$actual")"
  fi
}

assert_contains() {
  local desc="$1" needle="$2" haystack="$3"
  if [[ "$haystack" == *"$needle"* ]]; then
    PASS=$((PASS + 1))
    echo "  ok: $desc"
  else
    FAIL=$((FAIL + 1))
    echo "  FAIL: $desc (missing: $needle)"
  fi
}

# shellcheck source=/dev/null
source "$REPO_ROOT/install/lib.sh"
# shellcheck source=/dev/null
source "$REPO_ROOT/install/symlinks.sh"

echo "== find_owned_symlinks =="
tmp_scan="$(mktemp -d)"
mkdir -p "$tmp_scan/owner/config/nvim" "$tmp_scan/home/.config/nvim/lua"
echo "src" >"$tmp_scan/owner/config/nvim/init.lua"
echo "deep" >"$tmp_scan/owner/config/nvim/deep.lua"
ln -s "$tmp_scan/owner/config/nvim/init.lua" "$tmp_scan/home/.config/nvim/init.lua"
ln -s "$tmp_scan/owner/config/nvim/deep.lua" "$tmp_scan/home/.config/nvim/lua/deep.lua"
ln -s "/somewhere/else" "$tmp_scan/home/.config/foreign"
echo "real file" >"$tmp_scan/home/.config/realfile"

scan_out="$(find_owned_symlinks "$tmp_scan/home/.config" "$tmp_scan/owner" | sort)"
assert_eq "finds owned links at any depth, skips foreign links and files" \
  "$(printf '%s\n%s' \
    "$tmp_scan/home/.config/nvim/init.lua" \
    "$tmp_scan/home/.config/nvim/lua/deep.lua")" \
  "$scan_out"

assert_eq "missing dir yields empty output and rc 0" \
  "0|" \
  "$(out=$(find_owned_symlinks "$tmp_scan/nope" "$tmp_scan/owner"); echo "$?|$out")"

# Prefix must match on a path boundary: /owner-evil is not under /owner
ln -s "$tmp_scan/owner-evil-target" "$tmp_scan/home/.config/evil" 2>/dev/null || true
mkdir -p "$tmp_scan/owner-evil-target" 2>/dev/null || true
assert_eq "sibling dir sharing the owner prefix is not owned" \
  "" \
  "$(find_owned_symlinks "$tmp_scan/home/.config" "$tmp_scan/owner" | grep evil || true)"

echo "== is_owned_symlink =="
assert_eq "owned link -> 0" "0" \
  "$(is_owned_symlink "$tmp_scan/home/.config/nvim/init.lua" "$tmp_scan/owner"; echo $?)"
assert_eq "foreign link -> 1" "1" \
  "$(is_owned_symlink "$tmp_scan/home/.config/foreign" "$tmp_scan/owner"; echo $?)"
assert_eq "real file -> 1" "1" \
  "$(is_owned_symlink "$tmp_scan/home/.config/realfile" "$tmp_scan/owner"; echo $?)"
rm -rf "$tmp_scan"

echo
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash tests/test-uninstall.sh`
Expected: FAIL — `find_owned_symlinks: command not found` (non-zero exit, FAIL lines in output).

- [ ] **Step 3: Implement the functions**

In `install/symlinks.sh`, insert after `clean_broken_symlinks` (after line 179, before `update_manifest`):

```bash
# Is this path a symlink whose target lies under owner_root?
is_owned_symlink() {
    local link="$1"
    local owner="$2"

    [[ -L "$link" ]] || return 1
    local target
    target=$(readlink "$link" 2>/dev/null) || return 1
    [[ "$target" == "$owner"/* ]]
}

# Print all symlinks under a directory (unbounded depth) whose target lies
# under owner_root. Links are created per-file at arbitrary depth, so no
# -maxdepth here (unlike the detection-only scan in get_synced_configs).
find_owned_symlinks() {
    local dir="$1"
    local owner="$2"

    [[ -d "$dir" ]] || return 0
    local link
    while IFS= read -r link; do
        is_owned_symlink "$link" "$owner" && printf '%s\n' "$link"
    done < <(find "$dir" -type l 2>/dev/null)
    return 0
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bash tests/test-uninstall.sh`
Expected: PASS — `Results: N passed, 0 failed`, exit 0.

- [ ] **Step 5: Wire the new test file into `make test`**

In `Makefile`, replace the test target body (lines 116-121):

```makefile
## Run tests
test:
	@echo -e "$(YELLOW)Running tests...$(NC)"
	@status=0; \
	for t in tests/test-*.sh; do \
		bash "$$t" || status=1; \
	done; \
	exit $$status
```

(Keep the recipe's existing tab indentation.)

Run: `make test`
Expected: both `tests/test-bootstrap.sh` and `tests/test-uninstall.sh` run; exit 0.

- [ ] **Step 6: Shellcheck and commit**

Run: `shellcheck -S warning install/symlinks.sh tests/test-uninstall.sh`
Expected: no output, exit 0.

```bash
git add install/symlinks.sh tests/test-uninstall.sh Makefile
git commit -m "(install) Add owned-symlink scan helpers; run all test files in make test"
```

---

### Task 2: Backup discovery and restore (`newest_backup_path`, `restore_newest_backup`)

**Files:**
- Modify: `install/symlinks.sh` (append after `find_owned_symlinks` from Task 1)
- Test: `tests/test-uninstall.sh` (append section before the final Results block)

**Interfaces:**
- Consumes: `unique_backup_path` naming scheme (`<dest>.backup.<ts>[.N]`), `dot_warning`, `print_status` from `install/lib.sh`.
- Produces: `newest_backup_path <dest>` — prints path of the mtime-newest `<dest>.backup.*`; rc 1 and no output if none exist.
- Produces: `restore_newest_backup <dest>` — moves that backup to `<dest>`; rc 0 on restore; rc 1 if no backup or `<dest>` already exists (warns, touches nothing).

- [ ] **Step 1: Write the failing tests**

Append to `tests/test-uninstall.sh` (before the final `echo`/Results lines):

```bash
echo "== newest_backup_path / restore_newest_backup =="
tmp_bak="$(mktemp -d)"
echo "oldest" >"$tmp_bak/cfg.backup.20240101_000000"
echo "newest" >"$tmp_bak/cfg.backup.20250101_000000"
echo "collision" >"$tmp_bak/cfg.backup.20240101_000000.1"
# mtime decides, not the name: make the lexically-oldest file the newest
touch "$tmp_bak/cfg.backup.20240101_000000.1"
sleep 1 2>/dev/null || true
touch "$tmp_bak/cfg.backup.20240101_000000"

assert_eq "newest_backup_path picks by mtime" \
  "$tmp_bak/cfg.backup.20240101_000000" \
  "$(newest_backup_path "$tmp_bak/cfg")"

assert_eq "no backups -> rc 1, empty output" "1|" \
  "$(out=$(newest_backup_path "$tmp_bak/other"); echo "$?|$out")"

restore_newest_backup "$tmp_bak/cfg" >/dev/null
assert_eq "restore moves newest backup into place" \
  "oldest" "$(cat "$tmp_bak/cfg" 2>/dev/null || echo MISSING)"
assert_eq "older backups are left alone" \
  "yes" "$([[ -f "$tmp_bak/cfg.backup.20250101_000000" ]] && echo yes || echo no)"

# Refuses to overwrite: cfg now exists, another backup remains
restore_out="$(restore_newest_backup "$tmp_bak/cfg" 2>&1)"
restore_rc=$?
assert_eq "restore refuses to overwrite existing dest" "1" "$restore_rc"
assert_contains "restore warns when dest exists" "already exists" "$restore_out"
assert_eq "dest untouched by refused restore" "oldest" "$(cat "$tmp_bak/cfg")"
rm -rf "$tmp_bak"
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash tests/test-uninstall.sh`
Expected: FAIL — `newest_backup_path: command not found`.

- [ ] **Step 3: Implement**

In `install/symlinks.sh`, after `find_owned_symlinks`:

```bash
# Print the mtime-newest backup for a destination, if any.
# (The .N collision suffix breaks lexical ordering, so compare with -nt.)
newest_backup_path() {
    local dest="$1"
    local newest="" b
    for b in "$dest".backup.*; do
        [[ -e "$b" || -L "$b" ]] || continue
        if [[ -z "$newest" || "$b" -nt "$newest" ]]; then
            newest="$b"
        fi
    done
    [[ -n "$newest" ]] || return 1
    printf '%s\n' "$newest"
}

# Move the newest backup back into place. Never overwrites.
restore_newest_backup() {
    local dest="$1"
    local backup
    backup=$(newest_backup_path "$dest") || return 1
    if [[ -e "$dest" || -L "$dest" ]]; then
        dot_warning "Not restoring $backup: $dest already exists"
        return 1
    fi
    mv "$backup" "$dest"
    print_status "ok" "Restored: $dest (from ${backup##*/})"

    # Spec: older backups are left in place and reported
    local other
    for other in "$dest".backup.*; do
        [[ -e "$other" || -L "$other" ]] || continue
        print_status "info" "Older backup kept: $other"
    done
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bash tests/test-uninstall.sh`
Expected: PASS, exit 0.

- [ ] **Step 5: Shellcheck and commit**

Run: `shellcheck -S warning install/symlinks.sh tests/test-uninstall.sh`
Expected: clean.

```bash
git add install/symlinks.sh tests/test-uninstall.sh
git commit -m "(install) Add backup discovery and restore helpers"
```

---

### Task 3: Manifest hygiene (`update_manifest` dedup, `remove_manifest_entries`, drop `read_manifest`)

**Files:**
- Modify: `install/symlinks.sh:181-204` (`update_manifest`, `read_manifest`)
- Test: `tests/test-uninstall.sh` (append section)

**Interfaces:**
- Consumes: `MANIFEST_FILE` global (default `$HOME/.config/.dotfiles-manifest`), format `timestamp|src|dest` one per line.
- Produces: `update_manifest <src> <dest>` — same signature as today, but rewrites away any existing line with the same dest before appending (one line per dest, ever).
- Produces: `remove_manifest_entries <dest...>` — rewrites the manifest excluding lines whose third field matches any argument; rc 0 if manifest missing or no args.
- Removes: `read_manifest` (dead code — verify with `grep -rn read_manifest` first; only definition + this plan should hit).

- [ ] **Step 1: Verify `read_manifest` is dead**

Run: `grep -rn "read_manifest" --include="*.sh" --include="dotfiles" .`
Expected: only the definition in `install/symlinks.sh`. If a caller appears, stop and report.

- [ ] **Step 2: Write the failing tests**

Append to `tests/test-uninstall.sh`:

```bash
echo "== manifest hygiene =="
tmp_man="$(mktemp -d)"
(
  # shellcheck disable=SC2030  # subshell scoping is deliberate
  MANIFEST_FILE="$tmp_man/manifest"
  update_manifest "/src/a" "/dest/a"
  update_manifest "/src/b" "/dest/b"
  update_manifest "/src/a2" "/dest/a"   # same dest again -> replaces, not appends
)
assert_eq "update_manifest dedups by dest" "2" \
  "$(wc -l <"$tmp_man/manifest" | tr -d ' ')"
assert_contains "latest src wins for duplicated dest" "|/src/a2|/dest/a" \
  "$(cat "$tmp_man/manifest")"
assert_eq "a dest similar to another is not clobbered" "1" \
  "$(grep -c "|/dest/b$" "$tmp_man/manifest")"

(
  # shellcheck disable=SC2030,SC2031
  MANIFEST_FILE="$tmp_man/manifest"
  remove_manifest_entries "/dest/a"
)
assert_eq "remove_manifest_entries drops only the named dest" \
  "1" "$(wc -l <"$tmp_man/manifest" | tr -d ' ')"
assert_contains "surviving entry is the other dest" "|/dest/b" \
  "$(cat "$tmp_man/manifest")"

(
  # shellcheck disable=SC2030,SC2031
  MANIFEST_FILE="$tmp_man/missing-manifest"
  remove_manifest_entries "/dest/a"
)
assert_eq "remove on missing manifest is rc 0" "0" "$?"

assert_eq "read_manifest is gone" "1" \
  "$(type read_manifest >/dev/null 2>&1; echo $?)"
rm -rf "$tmp_man"
```

- [ ] **Step 3: Run test to verify it fails**

Run: `bash tests/test-uninstall.sh`
Expected: FAIL — dedup assertion sees 3 lines; `remove_manifest_entries: command not found`; `read_manifest is gone` fails.

- [ ] **Step 4: Implement**

Replace `update_manifest` and delete `read_manifest` in `install/symlinks.sh` (lines 181-204):

```bash
# Update manifest file with symlink information (one line per dest: any
# previous entry for the same dest is rewritten away before appending)
update_manifest() {
    local src="$1"
    local dest="$2"
    local timestamp
    timestamp=$(date +"%Y-%m-%d %H:%M:%S")

    local manifest_dir
    manifest_dir=$(dirname "$MANIFEST_FILE")
    [[ ! -d "$manifest_dir" ]] && mkdir -p "$manifest_dir"

    if [[ -f "$MANIFEST_FILE" ]]; then
        local tmp="$MANIFEST_FILE.tmp.$$"
        awk -F'|' -v d="$dest" '$3 != d' "$MANIFEST_FILE" >"$tmp"
        mv "$tmp" "$MANIFEST_FILE"
    fi
    echo "${timestamp}|${src}|${dest}" >>"$MANIFEST_FILE"
}

# Rewrite the manifest without the given destinations
remove_manifest_entries() {
    [[ -f "$MANIFEST_FILE" ]] || return 0
    [[ $# -gt 0 ]] || return 0

    local tmp="$MANIFEST_FILE.tmp.$$"
    printf '%s\n' "$@" |
        awk -F'|' 'NR == FNR { drop[$0] = 1; next } !($3 in drop)' \
            - "$MANIFEST_FILE" >"$tmp"
    mv "$tmp" "$MANIFEST_FILE"
}
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `bash tests/test-uninstall.sh && bash tests/test-bootstrap.sh`
Expected: both PASS (bootstrap tests exercise `create_symlink`→`update_manifest`; the backup-collision test sets its own `MANIFEST_FILE` and must stay green).

- [ ] **Step 6: Shellcheck and commit**

Run: `shellcheck -S warning install/symlinks.sh tests/test-uninstall.sh`
Expected: clean.

```bash
git add install/symlinks.sh tests/test-uninstall.sh
git commit -m "(install) Dedup manifest on write; add entry removal; drop dead read_manifest"
```

---

### Task 4: Removal engine (`uninstall_symlink`, `prune_empty_dirs`)

**Files:**
- Modify: `install/symlinks.sh` (append after `restore_newest_backup`)
- Test: `tests/test-uninstall.sh` (append section)

**Interfaces:**
- Consumes: `newest_backup_path`, `restore_newest_backup` (Task 2), `dry_run`, `print_status`.
- Produces: `uninstall_symlink <dest>` — rc 0 if a symlink was (or would be, under DRY_RUN) removed, rc 1 if `<dest>` is not a symlink. Honors `RESTORE` (default `true`) and `DRY_RUN`. Increments global `UNINSTALL_RESTORED` on each restore (caller initializes it; caller counts removals via the rc).
- Produces: `prune_empty_dirs <root>` — depth-first removal of empty dirs under and including `<root>`; prints `[DRY-RUN] rmdir <dir>` lines instead when `DRY_RUN` is set; rc 0 if root missing.

- [ ] **Step 1: Write the failing tests**

Append to `tests/test-uninstall.sh`:

```bash
echo "== uninstall_symlink =="
tmp_un="$(mktemp -d)"
echo "src" >"$tmp_un/src"
ln -s "$tmp_un/src" "$tmp_un/link"
echo "original" >"$tmp_un/link.backup.20250101_000000"
echo "keep me" >"$tmp_un/notalink"

UNINSTALL_RESTORED=0
RESTORE=true DRY_RUN="" uninstall_symlink "$tmp_un/link" >/dev/null
assert_eq "removes the link and restores backup" \
  "original" "$(cat "$tmp_un/link" 2>/dev/null || echo MISSING)"
assert_eq "restore counter incremented" "1" "$UNINSTALL_RESTORED"
assert_eq "restored dest is a regular file, not a link" \
  "no" "$([[ -L "$tmp_un/link" ]] && echo yes || echo no)"

assert_eq "non-symlink dest -> rc 1, untouched" "1" \
  "$(RESTORE=true DRY_RUN="" uninstall_symlink "$tmp_un/notalink" >/dev/null; echo $?)"
assert_eq "real file survives" "keep me" "$(cat "$tmp_un/notalink")"

# --no-restore path: link removed, backup stays put
ln -s "$tmp_un/src" "$tmp_un/link2"
echo "bak2" >"$tmp_un/link2.backup.20250101_000000"
UNINSTALL_RESTORED=0
RESTORE=false DRY_RUN="" uninstall_symlink "$tmp_un/link2" >/dev/null
assert_eq "no-restore removes link" \
  "no" "$([[ -e "$tmp_un/link2" || -L "$tmp_un/link2" ]] && echo yes || echo no)"
assert_eq "no-restore leaves backup in place" \
  "yes" "$([[ -f "$tmp_un/link2.backup.20250101_000000" ]] && echo yes || echo no)"
assert_eq "no-restore does not bump counter" "0" "$UNINSTALL_RESTORED"

# Dry run: nothing changes, planned actions are printed
ln -s "$tmp_un/src" "$tmp_un/link3"
echo "bak3" >"$tmp_un/link3.backup.20250101_000000"
UNINSTALL_RESTORED=0
dry_out="$(RESTORE=true DRY_RUN="dry_run" uninstall_symlink "$tmp_un/link3")"
assert_contains "dry run announces rm" "[DRY-RUN] rm $tmp_un/link3" "$dry_out"
assert_contains "dry run announces restore" "[DRY-RUN] mv $tmp_un/link3.backup.20250101_000000" "$dry_out"
assert_eq "dry run leaves the link" \
  "yes" "$([[ -L "$tmp_un/link3" ]] && echo yes || echo no)"

echo "== prune_empty_dirs =="
mkdir -p "$tmp_un/tree/a/b" "$tmp_un/tree/c"
echo "file" >"$tmp_un/tree/c/file"
DRY_RUN="" prune_empty_dirs "$tmp_un/tree"
assert_eq "empty subtree pruned" \
  "no" "$([[ -d "$tmp_un/tree/a" ]] && echo yes || echo no)"
assert_eq "non-empty dirs survive" \
  "yes" "$([[ -f "$tmp_un/tree/c/file" ]] && echo yes || echo no)"
mkdir -p "$tmp_un/empty-tree/x"
DRY_RUN="" prune_empty_dirs "$tmp_un/empty-tree"
assert_eq "fully-empty root is removed too" \
  "no" "$([[ -d "$tmp_un/empty-tree" ]] && echo yes || echo no)"
assert_eq "missing root is rc 0" "0" \
  "$(DRY_RUN="" prune_empty_dirs "$tmp_un/nope"; echo $?)"
rm -rf "$tmp_un"
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash tests/test-uninstall.sh`
Expected: FAIL — `uninstall_symlink: command not found`.

- [ ] **Step 3: Implement**

In `install/symlinks.sh`, after `restore_newest_backup`:

```bash
# Remove one owned symlink; restore its newest backup unless RESTORE=false.
# rc 0 when a link was (or would be) removed, rc 1 when dest is not a link.
# Increments UNINSTALL_RESTORED (caller-initialized) on restore.
uninstall_symlink() {
    local dest="$1"

    [[ -L "$dest" ]] || return 1
    dry_run rm "$dest"
    [[ -z "${DRY_RUN:-}" ]] && print_status "ok" "Removed: $dest"

    if [[ "${RESTORE:-true}" == "true" ]]; then
        local backup
        if backup=$(newest_backup_path "$dest"); then
            if [[ -n "${DRY_RUN:-}" ]]; then
                echo "[DRY-RUN] mv $backup $dest"
                UNINSTALL_RESTORED=$((${UNINSTALL_RESTORED:-0} + 1))
            elif restore_newest_backup "$dest"; then
                UNINSTALL_RESTORED=$((${UNINSTALL_RESTORED:-0} + 1))
            fi
        fi
    fi
    return 0
}

# Depth-first removal of empty directories under and including root
prune_empty_dirs() {
    local root="$1"

    [[ -d "$root" ]] || return 0
    if [[ -n "${DRY_RUN:-}" ]]; then
        find "$root" -depth -type d -empty -print 2>/dev/null |
            sed 's/^/[DRY-RUN] rmdir /'
    else
        find "$root" -depth -type d -empty -delete 2>/dev/null
    fi
    return 0
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bash tests/test-uninstall.sh`
Expected: PASS, exit 0.

- [ ] **Step 5: Shellcheck and commit**

Run: `shellcheck -S warning install/symlinks.sh tests/test-uninstall.sh`
Expected: clean.

```bash
git add install/symlinks.sh tests/test-uninstall.sh
git commit -m "(install) Add uninstall_symlink and prune_empty_dirs"
```

---

### Task 5: `cmd_uninstall` command in `bin/dotfiles`

**Files:**
- Modify: `bin/dotfiles` (new `cmd_uninstall` after `cmd_profile` ~line 303; `usage` lines 307-347; dispatch `case` lines 363-390; bump `DOTFILES_VERSION` to `1.1.0` at lines 4 and 16)
- Test: `tests/test-uninstall.sh` (append end-to-end section)

**Interfaces:**
- Consumes: `find_owned_symlinks`, `is_owned_symlink`, `uninstall_symlink`, `prune_empty_dirs`, `remove_manifest_entries` (Tasks 1-4); `DOTFILES_ROOT`, `CONFIG_DIR`, `MANIFEST_FILE` globals already set at the top of `bin/dotfiles`; `dry_run`, `dot_*`, `print_status` from `lib.sh`.
- Produces: `dotfiles uninstall [config...]` / `dotfiles u` per the spec: full mode prompts (skipped by `--yes`/`-y` or dry-run), per-config mode doesn't; `--dry-run/-n`, `--no-restore`, `--verbose/-v`; pseudo-config `bin`; summary counts; manifest deleted (full) or pruned (per-config); rc 0 on nothing-to-do, rc 1 on unknown config.

- [ ] **Step 1: Write the failing end-to-end tests**

Append to `tests/test-uninstall.sh`. These build a fake `$HOME` by hand (controlled, no bootstrap run needed) and call the real CLI:

```bash
echo "== dotfiles uninstall (end to end) =="
make_sandbox() {
  local home="$1"
  mkdir -p "$home/.config/nvim/lua" "$home/.config/tmux" "$home/.local/bin"
  # owned links into the real repo
  ln -s "$REPO_ROOT/config/nvim/init.lua" "$home/.config/nvim/init.lua"
  ln -s "$REPO_ROOT/config/tmux/tmux.conf" "$home/.config/tmux/tmux.conf"
  ln -s "$REPO_ROOT/config/zsh/zshenv" "$home/.zshenv"
  ln -s "$REPO_ROOT/bin/mkx" "$home/.local/bin/mkx"
  # a backup bootstrap would have made when it displaced a real nvim config
  echo "pre-dotfiles nvim" >"$home/.config/nvim/init.lua.backup.20250101_000000"
  # foreign link and real file that must survive any uninstall
  ln -s "/somewhere/else" "$home/.config/foreign"
  echo "hands off" >"$home/.config/realfile"
  # manifest with a stale duplicate, as real ones have
  {
    echo "2025-01-01 00:00:00|$REPO_ROOT/config/nvim/init.lua|$home/.config/nvim/init.lua"
    echo "2025-06-01 00:00:00|$REPO_ROOT/config/nvim/init.lua|$home/.config/nvim/init.lua"
    echo "2025-06-01 00:00:00|$REPO_ROOT/config/tmux/tmux.conf|$home/.config/tmux/tmux.conf"
  } >"$home/.config/.dotfiles-manifest"
}

# --- full uninstall ---
tmp_e2e="$(mktemp -d)"
make_sandbox "$tmp_e2e"
full_out="$(HOME="$tmp_e2e" "$REPO_ROOT/bin/dotfiles" uninstall --yes 2>&1)"
full_rc=$?
assert_eq "full uninstall exits 0" "0" "$full_rc"
assert_eq "nvim link replaced by restored backup" \
  "pre-dotfiles nvim" "$(cat "$tmp_e2e/.config/nvim/init.lua" 2>/dev/null || echo MISSING)"
assert_eq "tmux link gone and dir pruned" \
  "no" "$([[ -e "$tmp_e2e/.config/tmux" ]] && echo yes || echo no)"
assert_eq "zshenv home link gone" \
  "no" "$([[ -L "$tmp_e2e/.zshenv" ]] && echo yes || echo no)"
assert_eq "bin link gone" \
  "no" "$([[ -L "$tmp_e2e/.local/bin/mkx" ]] && echo yes || echo no)"
assert_eq ".local/bin itself survives" \
  "yes" "$([[ -d "$tmp_e2e/.local/bin" ]] && echo yes || echo no)"
assert_eq "foreign link survives" \
  "yes" "$([[ -L "$tmp_e2e/.config/foreign" ]] && echo yes || echo no)"
assert_eq "real file survives" \
  "hands off" "$(cat "$tmp_e2e/.config/realfile")"
assert_eq "manifest deleted" \
  "no" "$([[ -f "$tmp_e2e/.config/.dotfiles-manifest" ]] && echo yes || echo no)"
assert_contains "summary reports removals" "Removed" "$full_out"
rm -rf "$tmp_e2e"

# --- confirmation gate ---
tmp_e2e="$(mktemp -d)"
make_sandbox "$tmp_e2e"
HOME="$tmp_e2e" "$REPO_ROOT/bin/dotfiles" uninstall <<<"n" >/dev/null 2>&1
assert_eq "answering n aborts: links intact" \
  "yes" "$([[ -L "$tmp_e2e/.config/nvim/init.lua" ]] && echo yes || echo no)"
rm -rf "$tmp_e2e"

# --- per-config uninstall ---
tmp_e2e="$(mktemp -d)"
make_sandbox "$tmp_e2e"
HOME="$tmp_e2e" "$REPO_ROOT/bin/dotfiles" uninstall nvim >/dev/null 2>&1
assert_eq "per-config: nvim backup restored" \
  "pre-dotfiles nvim" "$(cat "$tmp_e2e/.config/nvim/init.lua" 2>/dev/null || echo MISSING)"
assert_eq "per-config: tmux untouched" \
  "yes" "$([[ -L "$tmp_e2e/.config/tmux/tmux.conf" ]] && echo yes || echo no)"
assert_eq "per-config: zshenv untouched" \
  "yes" "$([[ -L "$tmp_e2e/.zshenv" ]] && echo yes || echo no)"
assert_eq "per-config: manifest pruned to surviving config" \
  "1" "$(wc -l <"$tmp_e2e/.config/.dotfiles-manifest" | tr -d ' ')"
assert_contains "per-config: surviving manifest entry is tmux" \
  "tmux.conf" "$(cat "$tmp_e2e/.config/.dotfiles-manifest")"
rm -rf "$tmp_e2e"

# --- pseudo-config bin ---
tmp_e2e="$(mktemp -d)"
make_sandbox "$tmp_e2e"
HOME="$tmp_e2e" "$REPO_ROOT/bin/dotfiles" uninstall bin >/dev/null 2>&1
assert_eq "bin scope: mkx link gone" \
  "no" "$([[ -L "$tmp_e2e/.local/bin/mkx" ]] && echo yes || echo no)"
assert_eq "bin scope: configs untouched" \
  "yes" "$([[ -L "$tmp_e2e/.config/nvim/init.lua" ]] && echo yes || echo no)"
rm -rf "$tmp_e2e"

# --- dry run and no-restore ---
tmp_e2e="$(mktemp -d)"
make_sandbox "$tmp_e2e"
dry_e2e_out="$(HOME="$tmp_e2e" "$REPO_ROOT/bin/dotfiles" uninstall --dry-run 2>&1)"
assert_contains "dry run announces actions" "[DRY-RUN]" "$dry_e2e_out"
assert_eq "dry run changes nothing" \
  "yes" "$([[ -L "$tmp_e2e/.config/nvim/init.lua" && -f "$tmp_e2e/.config/.dotfiles-manifest" ]] && echo yes || echo no)"

HOME="$tmp_e2e" "$REPO_ROOT/bin/dotfiles" uninstall nvim --no-restore >/dev/null 2>&1
assert_eq "no-restore: link gone, no file restored" \
  "no" "$([[ -e "$tmp_e2e/.config/nvim/init.lua" ]] && echo yes || echo no)"
assert_eq "no-restore: backup still on disk" \
  "yes" "$([[ -f "$tmp_e2e/.config/nvim/init.lua.backup.20250101_000000" ]] && echo yes || echo no)"
rm -rf "$tmp_e2e"

# --- unknown config ---
tmp_e2e="$(mktemp -d)"
unknown_out="$(HOME="$tmp_e2e" "$REPO_ROOT/bin/dotfiles" uninstall bogus 2>&1)"
unknown_rc=$?
assert_eq "unknown config is an error" "1" "$unknown_rc"
assert_contains "error names the offender" "bogus" "$unknown_out"
rm -rf "$tmp_e2e"

# --- nothing to do ---
tmp_e2e="$(mktemp -d)"
mkdir -p "$tmp_e2e/.config"
nothing_out="$(HOME="$tmp_e2e" "$REPO_ROOT/bin/dotfiles" uninstall --yes 2>&1)"
nothing_rc=$?
assert_eq "nothing to uninstall exits 0" "0" "$nothing_rc"
assert_contains "reports nothing to do" "Nothing to uninstall" "$nothing_out"
rm -rf "$tmp_e2e"
```

Note: `make_sandbox` links real repo files (`config/nvim/init.lua`, `config/tmux/tmux.conf`, `config/zsh/zshenv`, `bin/mkx`) — all exist today. If one is ever renamed the test fails loudly, which is fine.

- [ ] **Step 2: Run test to verify it fails**

Run: `bash tests/test-uninstall.sh`
Expected: FAIL — `dotfiles uninstall` hits the `*` dispatch arm: "Unknown command: uninstall".

- [ ] **Step 3: Implement `cmd_uninstall`**

In `bin/dotfiles`, insert after `cmd_profile` (line 303):

```bash
# Command: uninstall - Remove repo-owned symlinks, restore backups
cmd_uninstall() {
  local assume_yes=false
  local -a configs=()

  export RESTORE=true
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --yes | -y) assume_yes=true; shift ;;
      --dry-run | -n) export DRY_RUN="dry_run"; shift ;;
      --no-restore) export RESTORE=false; shift ;;
      --verbose | -v) export VERBOSE=true; shift ;;
      *)
        if [[ -d "$CONFIG_DIR/$1" || "$1" == "bin" ]]; then
          configs+=("$1")
          shift
        else
          dot_error "Unknown config: $1"
          exit 1
        fi
        ;;
    esac
  done

  # Full uninstall is destructive enough to gate behind a prompt
  if [[ ${#configs[@]} -eq 0 && "$assume_yes" != "true" && -z "${DRY_RUN:-}" ]]; then
    local reply
    printf "Remove ALL dotfiles symlinks from this machine? [y/N] "
    read -r reply
    case "$reply" in
      y | Y | yes) ;;
      *)
        dot_info "Aborted"
        return 0
        ;;
    esac
  fi

  dot_title "Uninstalling Dotfiles Symlinks"

  # Gather targets: filesystem scan is the source of truth (see spec)
  local -a targets=()
  local link
  if [[ ${#configs[@]} -eq 0 ]]; then
    while IFS= read -r link; do targets+=("$link"); done \
      < <(find_owned_symlinks "$HOME/.config" "$DOTFILES_ROOT")
    while IFS= read -r link; do targets+=("$link"); done \
      < <(find_owned_symlinks "$HOME/.local/bin" "$DOTFILES_ROOT")
    for link in "$HOME/.zshenv" "$HOME/.lldbinit"; do
      is_owned_symlink "$link" "$DOTFILES_ROOT" && targets+=("$link")
    done
  else
    local config
    for config in "${configs[@]}"; do
      if [[ "$config" == "bin" ]]; then
        while IFS= read -r link; do targets+=("$link"); done \
          < <(find_owned_symlinks "$HOME/.local/bin" "$DOTFILES_ROOT/bin")
        continue
      fi
      while IFS= read -r link; do targets+=("$link"); done \
        < <(find_owned_symlinks "$HOME/.config/$config" "$CONFIG_DIR/$config")
      case "$config" in
        zsh) is_owned_symlink "$HOME/.zshenv" "$CONFIG_DIR/zsh" && targets+=("$HOME/.zshenv") ;;
        lldb) is_owned_symlink "$HOME/.lldbinit" "$CONFIG_DIR/lldb" && targets+=("$HOME/.lldbinit") ;;
      esac
    done
  fi

  if [[ ${#targets[@]} -eq 0 ]]; then
    dot_success "Nothing to uninstall"
    return 0
  fi

  # Remove links, restore backups, track what changed
  local removed=0
  export UNINSTALL_RESTORED=0
  local -a removed_dests=()
  local -A prune_roots=()
  local dest rel
  for dest in "${targets[@]}"; do
    if uninstall_symlink "$dest"; then
      removed=$((removed + 1))
      removed_dests+=("$dest")
      case "$dest" in
        "$HOME/.config"/*)
          rel="${dest#"$HOME"/.config/}"
          prune_roots["$HOME/.config/${rel%%/*}"]=1
          ;;
      esac
    fi
  done

  # Prune emptied config trees (never ~/.config itself or ~/.local/bin)
  local root
  for root in "${!prune_roots[@]}"; do
    prune_empty_dirs "$root"
  done

  # Manifest: full uninstall deletes it, scoped uninstall prunes it
  if [[ -z "${DRY_RUN:-}" ]]; then
    if [[ ${#configs[@]} -eq 0 ]]; then
      rm -f "$MANIFEST_FILE"
    elif [[ ${#removed_dests[@]} -gt 0 ]]; then
      # guard: "${removed_dests[@]}" on an empty array trips set -u on bash < 4.4
      remove_manifest_entries "${removed_dests[@]}"
    fi
  fi

  echo
  dot_title "Summary"
  if [[ -n "${DRY_RUN:-}" ]]; then
    print_status "info" "Would remove: $removed symlink(s), restore: $UNINSTALL_RESTORED backup(s)"
  else
    print_status "ok" "Removed symlinks: $removed"
    print_status "ok" "Restored backups: $UNINSTALL_RESTORED"
  fi
}
```

- [ ] **Step 4: Wire up dispatch, usage, and version**

In `bin/dotfiles`:

1. Version: line 4 comment `# Commands: sync, clean, status, watch` → `# Commands: sync, clean, status, watch, uninstall`; line 4/16 version strings `1.0.0` → `1.1.0`.

2. Dispatch `case` (after the `watch | w)` arm, line 378):

```bash
    uninstall | u)
      cmd_uninstall "$@"
      ;;
```

3. `usage` heredoc — add to Commands:

```
    uninstall, u     Remove dotfiles symlinks (all, or per config)
```

add to Options:

```
    -y, --yes          Skip confirmation (for uninstall)
    --no-restore       Don't restore backups (for uninstall)
```

add to Examples:

```
    dotfiles u                 # Uninstall everything (asks first)
    dotfiles u nvim            # Uninstall only nvim's links
    dotfiles u -n              # Preview a full uninstall
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `bash tests/test-uninstall.sh`
Expected: PASS, exit 0.

- [ ] **Step 6: Shellcheck and commit**

Run: `shellcheck -S warning bin/dotfiles tests/test-uninstall.sh`
Expected: clean. (Watch SC2168/SC2034: `rel` and `root` are declared `local` inside `cmd_uninstall`, which is legal; `UNINSTALL_RESTORED` is exported before use.)

```bash
git add bin/dotfiles tests/test-uninstall.sh
git commit -m "(bin) Add dotfiles uninstall command"
```

---

### Task 6: Docs, backlog, full verification

**Files:**
- Modify: `README.md:76-78` (utility command list)
- Modify: `CLAUDE.md:33-35` (symlink management section)
- Modify: `docs/REVIEW-BACKLOG.md:10-13` (check off the uninstall item)

**Interfaces:**
- Consumes: the finished command from Task 5.
- Produces: user-facing docs in sync with the code; the backlog item closed.

- [ ] **Step 1: Update README.md**

After line 78 (`dotfiles clean     # remove broken symlinks`), add:

```
dotfiles uninstall # remove dotfiles symlinks, restore backed-up originals
```

- [ ] **Step 2: Update CLAUDE.md**

After line 35 (`dotfiles status ...`), add:

```
dotfiles uninstall                       # Remove symlinks, restore backups
dotfiles uninstall nvim                  # Remove one config's symlinks
```

- [ ] **Step 3: Check off the backlog item**

In `docs/REVIEW-BACKLOG.md`, change the first Install/shell-tooling item from `- [ ]` to `- [x]` and append to its text: `Done: implemented 2026-07-10 (uninstall command; manifest now deduped on write and consumed/pruned on uninstall; read_manifest removed).`

- [ ] **Step 4: Full verification**

Run: `make test`
Expected: all test files pass, exit 0.

Run: `shellcheck -S warning bootstrap.sh install/*.sh bin/dotfiles tests/*.sh`
Expected: clean.

Run a live smoke test against a scratch HOME (no real HOME touched):

```bash
tmp="$(mktemp -d)" && HOME="$tmp" ./bootstrap.sh --sync --profile minimal >/dev/null 2>&1; \
HOME="$tmp" ./bin/dotfiles uninstall --yes && \
find "$tmp/.config" -type l | wc -l && rm -rf "$tmp"
```

Expected: uninstall summary with non-zero removed count; final `find` prints `0`.

- [ ] **Step 5: Commit**

```bash
git add README.md CLAUDE.md docs/REVIEW-BACKLOG.md
git commit -m "(docs) Document dotfiles uninstall; close backlog item"
```
