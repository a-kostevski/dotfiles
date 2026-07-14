#!/usr/bin/env bash
# Focused regression tests for config/macos/defaults.zsh.

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
export REPO_ROOT
# shellcheck source=tests/lib.sh
source "$REPO_ROOT/tests/lib.sh"

if ! command -v zsh >/dev/null 2>&1; then
  echo "skip: zsh is required to test macOS defaults helpers"
  exit 0
fi

echo "== macOS defaults safeguards =="
tmp_defaults="$(mktemp -d)"
mkdir -p "$tmp_defaults/bin" "$tmp_defaults/home/Library/Preferences" "$tmp_defaults/zsh"

cat >"$tmp_defaults/bin/PlistBuddy" <<'EOF'
#!/bin/bash
set -eu

command="$2"
printf '%s\n' "$command" >>"$PLISTBUDDY_LOG"

case "$command" in
  Print*|Set*) [[ "${PLISTBUDDY_EXISTING:-}" == "true" ]] && exit 0 || exit 1 ;;
  Add*) [[ "${PLISTBUDDY_EXISTING:-}" == "true" ]] && exit 1 || exit 0 ;;
esac
EOF
chmod +x "$tmp_defaults/bin/PlistBuddy"

export TEST_HOME="$tmp_defaults/home"
export TEST_PLISTBUDDY="$tmp_defaults/bin/PlistBuddy"
export PLISTBUDDY_LOG="$tmp_defaults/plistbuddy.log"
export ZDOTDIR="$tmp_defaults/zsh"
defaults_out="$(zsh -f "$REPO_ROOT/tests/macos-defaults-regression.zsh" 2>&1)"
defaults_rc=$?
plist_commands="$(<"$PLISTBUDDY_LOG")"

assert_eq "Finder plist setup succeeds when keys are absent" "0" "$defaults_rc"
assert_eq "Finder plist setup stays quiet" "" "$defaults_out"
assert_contains "creates missing DesktopViewSettings dictionary" "Add :DesktopViewSettings dict" "$plist_commands"
assert_contains "creates missing icon settings dictionary" "Add :DesktopViewSettings:IconViewSettings dict" "$plist_commands"
assert_contains "adds missing item-info value" "Add :DesktopViewSettings:IconViewSettings:showItemInfo bool true" "$plist_commands"
assert_contains "adds missing label placement value" "Add :DesktopViewSettings:IconViewSettings:labelOnBottom bool false" "$plist_commands"

: >"$PLISTBUDDY_LOG"
export PLISTBUDDY_EXISTING=true
existing_out="$(zsh -f "$REPO_ROOT/tests/macos-defaults-regression.zsh" 2>&1)"
existing_rc=$?
existing_commands="$(<"$PLISTBUDDY_LOG")"
existing_adds=0
[[ "$existing_commands" == *"Add "* ]] && existing_adds=1

assert_eq "Finder plist setup is idempotent when keys exist" "0" "$existing_rc"
assert_eq "existing Finder plist setup stays quiet" "" "$existing_out"
assert_contains "existing Finder plist setup updates the item-info value" "Set :DesktopViewSettings:IconViewSettings:showItemInfo true" "$existing_commands"
assert_eq "existing Finder plist setup does not add duplicate keys" "0" "$existing_adds"

rm -rf "$tmp_defaults"

echo
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
