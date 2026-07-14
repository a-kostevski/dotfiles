#!/usr/bin/env bash
# Edge-case tests for the smaller bin/ helper scripts (BIN-01..03 / TEST-05).
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
export REPO_ROOT
# shellcheck source=tests/lib.sh
source "$REPO_ROOT/tests/lib.sh"

# run_capped <max_bytes> <cmd...>: run a command capturing at most <max_bytes>
# of merged stdout+stderr into CAP_OUT and its exit code into CAP_RC. Output is
# piped through `head -c`, so a runaway (pre-fix infinite loop) receives SIGPIPE
# and dies instead of hanging the suite.
run_capped() {
  local max="$1"; shift
  local rc_file; rc_file="$(mktemp)"
  CAP_OUT="$({ "$@"; printf '%s' "$?" > "$rc_file"; } 2>&1 | head -c "$max")"
  CAP_RC="$(cat "$rc_file" 2>/dev/null || printf '999')"
  [ -n "$CAP_RC" ] || CAP_RC=139   # producer killed by SIGPIPE before recording
  rm -f "$rc_file"
}

echo "== bin/confirm EOF handling (BIN-01) =="
confirm_bin="$REPO_ROOT/bin/confirm"

# Closed stdin must decline (exit 1), not loop forever printing the error.
run_capped 65536 "$confirm_bin" < /dev/null
assert_eq "confirm on EOF exits 1 (decline)" "1" "$CAP_RC"
loop_count="$(printf '%s' "$CAP_OUT" | grep -c "Please answer yes or no." || true)"
assert_eq "confirm on EOF does not loop (no repeated error)" "0" "$loop_count"

# Interactive answers still work.
run_capped 4096 "$confirm_bin" <<< "y"
assert_eq "confirm 'y' exits 0" "0" "$CAP_RC"
run_capped 4096 "$confirm_bin" <<< "n"
assert_eq "confirm 'n' exits 1" "1" "$CAP_RC"

echo
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
