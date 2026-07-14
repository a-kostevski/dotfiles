#!/usr/bin/env bash
# Unit tests for the declarative package manifest reader (install/packages.sh).
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$REPO_ROOT" || exit 1

# shellcheck source=tests/lib.sh
source "$REPO_ROOT/tests/lib.sh"
export dot_root="$REPO_ROOT"
# shellcheck source=/dev/null
source "$REPO_ROOT/install/lib.sh"
# shellcheck source=/dev/null
source "$REPO_ROOT/install/packages.sh"

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

echo "== validate_tier / resolve_package_tier =="
validate_tier minimal && vt_min=0 || vt_min=1
assert_eq "validate_tier accepts minimal" "0" "$vt_min"
validate_tier bogus 2>/dev/null && vt_bad=0 || vt_bad=1
assert_eq "validate_tier rejects bogus" "1" "$vt_bad"
assert_eq "profile standard -> standard packages" "standard" "$(resolve_package_tier standard)"
assert_eq "profile all -> full packages" "full" "$(resolve_package_tier all)"
assert_eq "override wins over profile" "full" "$(resolve_package_tier minimal full)"

echo
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
