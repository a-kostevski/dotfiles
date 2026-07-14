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

echo "== bin/nshift duration validation + PID safety (BIN-02) =="
if ! command -v zsh >/dev/null 2>&1; then
  echo "  skip: zsh is required to test nshift"
else
  ns_sandbox="$(mktemp -d)"
  mkdir -p "$ns_sandbox/bin" "$ns_sandbox/fakebin" "$ns_sandbox/run"
  cp "$REPO_ROOT/bin/nshift" "$ns_sandbox/bin/nshift"
  : > "$ns_sandbox/bin/nightshift-helper.swift"
  chmod +x "$ns_sandbox/bin/nightshift-helper.swift"

  # Stub uname -> Darwin so check_platform passes on Linux CI.
  make_fake_bin "$ns_sandbox/fakebin" uname 'echo Darwin'
  # Stub swift: log argv; emulate helper status/toggle output.
  cat > "$ns_sandbox/fakebin/swift" <<EOF
#!/usr/bin/env bash
echo "swift \$*" >> "$ns_sandbox/swift.log"
case "\$2" in
  status) echo off ;;
  toggle) echo on ;;
esac
exit 0
EOF
  chmod +x "$ns_sandbox/fakebin/swift"

  export XDG_RUNTIME_DIR="$ns_sandbox/run"
  ns_run() { PATH="$ns_sandbox/fakebin:$PATH" zsh -f "$ns_sandbox/bin/nshift" "$@"; }

  # Invalid durations exit 1 with a clear message and NO side effects.
  for bad in 0 -1 0.5 abc; do
    : > "$ns_sandbox/swift.log"
    out="$(ns_run for "$bad" 2>&1)"; rc=$?
    assert_eq "nshift for '$bad' exits 1" "1" "$rc"
    assert_contains "nshift for '$bad' reports invalid duration" "Invalid duration" "$out"
    onlog="$(grep -c 'swift .* on' "$ns_sandbox/swift.log" 2>/dev/null || true)"
    assert_eq "nshift for '$bad' does not enable Night Shift" "0" "$onlog"
    assert_eq "nshift for '$bad' writes no timer pid file" "0" \
      "$(ls "$ns_sandbox/run/nshift/timer.pid" 2>/dev/null | wc -l | tr -d ' ')"
  done

  # Process-identity guard: a recorded PID whose command lacks our marker
  # (a recycled/foreign PID) must NOT be killed by `nshift cancel`.
  sleep 120 &
  foreign_pid=$!
  mkdir -p "$ns_sandbox/run/nshift"
  echo "$foreign_pid" > "$ns_sandbox/run/nshift/timer.pid"
  ns_run -q cancel >/dev/null 2>&1 || true
  if kill -0 "$foreign_pid" 2>/dev/null; then ns_alive=yes; else ns_alive=no; fi
  assert_eq "nshift cancel does not kill an unrelated (recycled) PID" "yes" "$ns_alive"
  kill "$foreign_pid" 2>/dev/null || true

  rm -rf "$ns_sandbox"
  unset XDG_RUNTIME_DIR
fi

echo
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
