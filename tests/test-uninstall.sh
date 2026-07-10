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
