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

# mv failure must fail loudly (skip as root: root ignores mode bits)
if [[ $EUID -ne 0 ]]; then
  tmp_ro="$(mktemp -d)"
  echo "content" >"$tmp_ro/cfg.backup.20240101_000000"
  chmod 555 "$tmp_ro"
  ro_out="$(restore_newest_backup "$tmp_ro/cfg" 2>&1)"
  ro_rc=$?
  assert_eq "restore returns rc 1 when mv fails" "1" "$ro_rc"
  assert_contains "restore reports mv failure" "Failed to restore" "$ro_out"
  assert_eq "backup still exists after failed restore" \
    "yes" "$([[ -f "$tmp_ro/cfg.backup.20240101_000000" ]] && echo yes || echo no)"
  chmod 755 "$tmp_ro"
  rm -rf "$tmp_ro"
fi

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
  # shellcheck disable=SC2030,SC2031,SC2034
  MANIFEST_FILE="$tmp_man/missing-manifest"
  remove_manifest_entries "/dest/a"
)
assert_eq "remove on missing manifest is rc 0" "0" "$?"

assert_eq "read_manifest is gone" "1" \
  "$(type read_manifest >/dev/null 2>&1; echo $?)"
rm -rf "$tmp_man"

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

echo
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
