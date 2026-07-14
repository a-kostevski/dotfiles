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
