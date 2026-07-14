#!/usr/bin/env bash
# Unit tests for the Ubuntu package executor plan (install/install-ubuntu.sh):
# required apt selection is pure, optional extras are retried/summarized
# without aborting, and the eza repo is HTTPS-only.
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
# shellcheck source=/dev/null
source "$REPO_ROOT/install/install-ubuntu.sh"

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

echo
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
