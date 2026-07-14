#!/usr/bin/env bash
# Unit tests for the retry / optional-step helpers in install/lib.sh.
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$REPO_ROOT" || exit 1

# shellcheck source=tests/lib.sh
source "$REPO_ROOT/tests/lib.sh"
export dot_root="$REPO_ROOT"
# shellcheck source=/dev/null
source "$REPO_ROOT/install/lib.sh"

echo "== retry / optional steps =="
_fail_twice_count=0
_fail_twice() { _fail_twice_count=$((_fail_twice_count+1)); (( _fail_twice_count >= 3 )); }
DRY_RUN='' retry 5 0 -- _fail_twice && r_ok=0 || r_ok=1
assert_eq "retry succeeds after transient failures" "0" "$r_ok"

_always_fail() { return 1; }
DRY_RUN='' retry 2 0 -- _always_fail && r_bad=0 || r_bad=1
assert_eq "retry gives up after attempts" "1" "$r_bad"

OPTIONAL_FAILURES=()
run_optional_step "widget" _always_fail
assert_eq "optional failure does not abort" "widget" "${OPTIONAL_FAILURES[*]}"
summary="$(report_optional_failures 2>&1)"
assert_contains "summary lists failed step" "widget" "$summary"

echo
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
