#!/usr/bin/env bash
# Unit tests for the macOS package executor's pure planning function
# (install/homebrew.sh:generate_brewfile). Sourcing homebrew.sh must not
# invoke brew: the trailing "main" is guarded, so this only exercises
# generate_brewfile directly.
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$REPO_ROOT" || exit 1

# shellcheck source=tests/lib.sh
source "$REPO_ROOT/tests/lib.sh"
export dot_root="$REPO_ROOT"
export PACKAGE_TIER=standard
# shellcheck source=/dev/null
source "$REPO_ROOT/install/lib.sh"
# shellcheck source=/dev/null
source "$REPO_ROOT/install/symlinks.sh"
# shellcheck source=/dev/null
source "$REPO_ROOT/install/packages.sh"
# shellcheck source=/dev/null
source "$REPO_ROOT/install/homebrew.sh"

echo "== macOS Brewfile generation =="
bf="$(mktemp)"
generate_brewfile standard "$bf"
gen="$(cat "$bf")"; rm -f "$bf"
assert_contains "standard Brewfile has neovim formula" 'brew "neovim"' "$gen"
assert_eq "standard Brewfile has no casks" "" "$(grep '^cask ' <<<"$gen" || true)"

bf2="$(mktemp)"
generate_brewfile full "$bf2"
genf="$(cat "$bf2")"; rm -f "$bf2"
assert_contains "full Brewfile includes kitty cask" 'cask "kitty"' "$genf"

echo
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
