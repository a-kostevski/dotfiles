# Helper Scripts Hardening Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Harden the smaller `bin/` helper executables and close the CI lint / edge-test gaps around them (review items BIN-01..04, KITTY-02, TEST-05, and verify CLI-01).

**Architecture:** Small, localized fixes to standalone shell scripts plus a shebang-driven shellcheck gate shared by `make` and CI, and a new edge-case test file in the existing bash harness. No changes to unrelated scripts.

**Tech Stack:** POSIX sh, bash, zsh (nshift), macOS `defaults`/`swift`/`ps`, ShellCheck, GNU Make, GitHub Actions. Test harness: `tests/lib.sh` (`assert_eq`, `assert_contains`, `make_fake_bin`).

## Global Constraints

- Work only in the worktree at `.worktrees/helper-scripts` on branch `helper-scripts-hardening`. Never edit `~/.config/` directly.
- Zsh files (`bin/nshift`, `bin/countdown`, `tests/*.zsh`) are parsed with `zsh -n`, never shellchecked (ShellCheck errors SC1071 on zsh). The bash shellcheck gate must not regress.
- Every test file: `set -uo pipefail`; `REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"; export REPO_ROOT`; `source "$REPO_ROOT/tests/lib.sh"`; end with `echo; echo "Results: $PASS passed, $FAIL failed"; [[ $FAIL -eq 0 ]]`.
- `make test` runs every `tests/test-*.sh` under bash on macOS and Ubuntu CI; guard zsh-dependent tests with `command -v zsh` and `echo "skip: ..."; exit 0` when absent (existing pattern).
- `nshift for [HOURS]` accepts positive whole integers only (`^[0-9]+$`, reject all-zeros). No `bc` anywhere.
- Do not push. Commit per task with the messages shown.
- Run all commands from the worktree root: `cd /Users/antonkostevski/dev/repos/github.com/a-kostevski/dotfiles/.worktrees/helper-scripts` (abbreviated `$WT` below).

---

### Task 1: BIN-01 — `confirm` treats EOF as decline

**Files:**
- Modify: `bin/confirm`
- Create: `tests/test-bin-helpers.sh` (new shared test file; confirm section)

**Interfaces:**
- Produces: `tests/test-bin-helpers.sh` with a top-of-file helper `run_capped <max_bytes> <cmd...>` that sets `CAP_OUT` and `CAP_RC`. Later tasks (2, 3) append their own sections to this file.

- [ ] **Step 1: Write the failing test**

Create `tests/test-bin-helpers.sh`:

```bash
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd $WT && bash tests/test-bin-helpers.sh`
Expected: FAIL on "confirm on EOF exits 1" (CAP_RC is 139/SIGPIPE, not 1) and/or "does not loop" (loop_count > 0), because the current script loops forever on EOF. The `run_capped` cap prevents a hang.

- [ ] **Step 3: Write minimal implementation**

Replace `bin/confirm` entirely with:

```sh
#!/bin/sh

confirm() {
   while true; do
      printf "Do you wish to continue? (y/n): "
      if ! read -r yn; then
         # EOF / closed stdin: decline rather than loop forever.
         printf '\n' >&2
         exit 1
      fi
      case $yn in
         [Yy]* | [Yy][Ee][Ss]) return 0 ;;
         [Nn]* | [Nn][Oo]) exit 1 ;;
         *) echo "Please answer yes or no." ;;
      esac
   done
}

# Run when executed (the file previously only defined the function,
# making the command a silent no-op)
confirm "$@"
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd $WT && bash tests/test-bin-helpers.sh`
Expected: PASS — `Results: 4 passed, 0 failed`.

- [ ] **Step 5: Commit**

```bash
cd $WT
git add bin/confirm tests/test-bin-helpers.sh
git commit -m "bin: treat EOF as decline in confirm (BIN-01); add edge tests (TEST-05)"
```

---

### Task 2: BIN-02 — `nshift` validate-first, drop `bc`, owned PID dir + process identity

**Files:**
- Modify: `bin/nshift`
- Modify: `tests/test-bin-helpers.sh` (append nshift section)

**Interfaces:**
- Consumes: `run_capped` from Task 1 (not required here; nshift exits promptly).
- Produces: `bin/nshift` with `readonly TIMER_MARKER="nshift-timer"`, `readonly NSHIFT_RUNTIME_DIR`, `readonly TIMER_PID_FILE`, and functions `ensure_runtime_dir`, `pid_is_our_timer <pid>`.

- [ ] **Step 1: Write the failing test**

Append to `tests/test-bin-helpers.sh` **before** the final `echo/Results/[[ ]]` block (move those three lines to the end after this section):

```bash
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
    onlog="$(grep -c 'swift .* on' "$ns_sandbox/swift.log" 2>/dev/null || echo 0)"
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
```

(Ensure the file still ends with the `echo; echo "Results: ..."; [[ $FAIL -eq 0 ]]` block.)

- [ ] **Step 2: Run test to verify it fails**

Run: `cd $WT && bash tests/test-bin-helpers.sh`
Expected: FAIL — current `nshift` validates after arithmetic and depends on `bc`; `for 0.5` is currently accepted, and `for 0`/`-1` error via `bc` (which may be absent). The process-identity assertion fails because current `cancel_timer` kills any live PID via `kill -0`.

- [ ] **Step 3: Write minimal implementation**

In `bin/nshift`, change the PID-file constants. Replace:

```zsh
readonly TIMER_PID_FILE="${TMPDIR:-/tmp}/nshift-timer.pid"
```

with:

```zsh
readonly TIMER_MARKER="nshift-timer"
readonly NSHIFT_RUNTIME_DIR="${XDG_RUNTIME_DIR:-${TMPDIR:-/tmp}}/nshift"
readonly TIMER_PID_FILE="$NSHIFT_RUNTIME_DIR/timer.pid"
```

Add two helpers immediately after the `error_exit` function definition:

```zsh
# Create an owned, private runtime dir for timer state.
ensure_runtime_dir() {
  [[ -d "$NSHIFT_RUNTIME_DIR" ]] || mkdir -p "$NSHIFT_RUNTIME_DIR"
  chmod 700 "$NSHIFT_RUNTIME_DIR" 2>/dev/null || true
}

# True if <pid> is alive AND is one of our timer processes. The timer is
# launched with our marker in its argv, so a stale pid file whose PID was
# recycled by an unrelated process fails this check and is left untouched.
pid_is_our_timer() {
  local pid="$1"
  [[ -n "$pid" ]] || return 1
  kill -0 "$pid" 2>/dev/null || return 1
  local cmd
  cmd=$(ps -o command= -p "$pid" 2>/dev/null) || return 1
  [[ "$cmd" == *"$TIMER_MARKER"* ]]
}
```

Replace `cancel_timer` with:

```zsh
# Cancel any existing timer (only if it is verifiably ours)
cancel_timer() {
  [[ -f "$TIMER_PID_FILE" ]] || return 0
  local pid
  pid=$(cat "$TIMER_PID_FILE" 2>/dev/null)
  if pid_is_our_timer "$pid"; then
    kill "$pid" 2>/dev/null || true
    [[ "$QUIET" != true ]] && echo "  ${YELLOW}Cancelled previous timer${RESET}"
  fi
  rm -f "$TIMER_PID_FILE"
}
```

Replace `enable_for_duration` with:

```zsh
# Enable Night Shift for a specified duration
enable_for_duration() {
  local hours="${1:-$DEFAULT_HOURS}"

  # Validate the duration format FIRST, before any arithmetic or side effects.
  # Positive whole hours only; no bc dependency.
  if ! [[ "$hours" =~ ^[0-9]+$ ]] || [[ "$hours" =~ ^0+$ ]]; then
    error_exit "Invalid duration: $hours (must be a positive whole number of hours)"
  fi

  local seconds=$((hours * 3600))

  # Cancel any existing timer
  cancel_timer

  # Enable Night Shift
  run_helper on >/dev/null

  # Start background timer, tagged with our marker so it can be identified
  # later even if its PID is recycled after it exits.
  ensure_runtime_dir
  zsh -c 'sleep "$1"; swift "$2" off 2>/dev/null; rm -f "$3"' \
    "$TIMER_MARKER" "$seconds" "$HELPER" "$TIMER_PID_FILE" &
  echo $! > "$TIMER_PID_FILE"
  disown

  if [[ "$QUIET" != true ]]; then
    echo ""
    echo "  ${GREEN}Night Shift enabled for ${hours} hour(s)${RESET}"
    echo "  ${BLUE}Will automatically disable at $(date -v+${seconds}S '+%H:%M')${RESET}"
    echo ""
  fi
}
```

In `show_status`, replace the timer block:

```zsh
  # Show timer status
  if [[ -f "$TIMER_PID_FILE" ]]; then
    local pid
    pid=$(cat "$TIMER_PID_FILE" 2>/dev/null)
    if pid_is_our_timer "$pid"; then
      echo "Timer: ${YELLOW}Active${RESET} (will auto-disable)"
    fi
  fi
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd $WT && bash tests/test-bin-helpers.sh`
Expected: PASS. Also verify parse + lint:
Run: `cd $WT && zsh -n bin/nshift && echo OK`
Expected: `OK`.

- [ ] **Step 5: Commit**

```bash
cd $WT
git add bin/nshift tests/test-bin-helpers.sh
git commit -m "bin: nshift validate-first, drop bc, owned PID dir + identity check (BIN-02)"
```

---

### Task 3: BIN-03 — `osx-clock-toggle` becomes a composite wind-down wrapper

**Files:**
- Modify: `bin/osx-clock-toggle`
- Modify: `tests/test-bin-helpers.sh` (append osx-clock-toggle section)

**Interfaces:**
- Consumes: sibling scripts `cantsleep` and `nshift` resolved relative to the wrapper's own directory.
- Produces: wrapper delegating clock toggle to `cantsleep` and Night Shift toggle to `nshift toggle`.

- [ ] **Step 1: Write the failing test**

Append to `tests/test-bin-helpers.sh` (before the final Results block):

```bash
echo "== bin/osx-clock-toggle composite wrapper (BIN-03) =="
oct_sandbox="$(mktemp -d)"
mkdir -p "$oct_sandbox/bin"
cp "$REPO_ROOT/bin/osx-clock-toggle" "$oct_sandbox/bin/osx-clock-toggle"
oct_log="$oct_sandbox/calls.log"
cat > "$oct_sandbox/bin/cantsleep" <<EOF
#!/usr/bin/env bash
echo "cantsleep \$*" >> "$oct_log"
EOF
cat > "$oct_sandbox/bin/nshift" <<EOF
#!/usr/bin/env bash
echo "nshift \$*" >> "$oct_log"
EOF
chmod +x "$oct_sandbox/bin/cantsleep" "$oct_sandbox/bin/nshift"

: > "$oct_log"
"$oct_sandbox/bin/osx-clock-toggle" >/dev/null 2>&1
oct_calls="$(cat "$oct_log")"
assert_contains "bare toggle delegates clock to cantsleep" "cantsleep" "$oct_calls"
assert_contains "bare toggle toggles Night Shift" "nshift toggle" "$oct_calls"

: > "$oct_log"
"$oct_sandbox/bin/osx-clock-toggle" --quiet >/dev/null 2>&1
oct_q="$(cat "$oct_log")"
assert_contains "quiet forwards --quiet to cantsleep" "cantsleep --quiet" "$oct_q"
assert_contains "quiet forwards -q to nshift" "nshift -q toggle" "$oct_q"

: > "$oct_log"
"$oct_sandbox/bin/osx-clock-toggle" --status >/dev/null 2>&1
oct_s="$(cat "$oct_log")"
assert_contains "status queries cantsleep" "cantsleep --status" "$oct_s"
assert_contains "status queries nshift" "nshift status" "$oct_s"

rm -rf "$oct_sandbox"
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd $WT && bash tests/test-bin-helpers.sh`
Expected: FAIL — current `osx-clock-toggle` calls `defaults` directly and never invokes `cantsleep`/`nshift`, so nothing is written to the call log.

- [ ] **Step 3: Write minimal implementation**

Replace `bin/osx-clock-toggle` entirely with:

```sh
#!/bin/sh

#######################################
# Script Name: osx-clock-toggle
# Description: Wind-down toggle. Flips the menu bar clock (delegated to
#              cantsleep) and Night Shift (delegated to nshift) together.
#              Thin wrapper: the real logic lives in those two scripts.
# Usage: osx-clock-toggle [--help|--status|--quiet]
#######################################

set -eu

dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)
cantsleep="$dir/cantsleep"
nshift="$dir/nshift"

case "${1:-}" in
   -h | --help)
      cat <<EOF
osx-clock-toggle - wind-down toggle for the menu bar clock and Night Shift

USAGE:
    osx-clock-toggle [OPTIONS]

OPTIONS:
    -h, --help      Show this help message
    -s, --status    Show clock and Night Shift status without changing anything
    -q, --quiet     Toggle without messages

DESCRIPTION:
    Toggles the macOS menu bar clock (delegated to cantsleep) and Night Shift
    (delegated to nshift) in one step. The two toggle independently.
EOF
      ;;
   -s | --status)
      "$cantsleep" --status
      "$nshift" status
      ;;
   -q | --quiet)
      "$cantsleep" --quiet
      "$nshift" -q toggle
      ;;
   "")
      "$cantsleep"
      "$nshift" toggle
      ;;
   *)
      echo "Unknown option: $1. Use --help for usage information." >&2
      exit 1
      ;;
esac
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd $WT && bash tests/test-bin-helpers.sh`
Expected: PASS — all sections green.
Run: `cd $WT && shellcheck -S warning bin/osx-clock-toggle && echo OK`
Expected: `OK` (no findings).

- [ ] **Step 5: Commit**

```bash
cd $WT
git add bin/osx-clock-toggle tests/test-bin-helpers.sh
git commit -m "bin: osx-clock-toggle delegates clock+Night Shift toggle (BIN-03)"
```

---

### Task 4: BIN-04 — fix `cantsleep` SC2155 warnings

**Files:**
- Modify: `bin/cantsleep`

**Interfaces:** none (behavior unchanged; only declare/assign split).

- [ ] **Step 1: Write the failing check**

Run: `cd $WT && shellcheck -S warning bin/cantsleep`
Expected: FAIL — 8 × SC2155 at lines 11, 16, 17, 18, 19, 49, 86, 96.

- [ ] **Step 2: Implement — split declaration from assignment**

Edit `bin/cantsleep`:

Line 11 — replace:
```bash
readonly SCRIPT_NAME=$(basename "$0")
```
with:
```bash
SCRIPT_NAME=$(basename "$0")
readonly SCRIPT_NAME
```

Lines 15-25 — replace the color block:
```bash
if command -v tput >/dev/null 2>&1 && [[ -t 1 ]]; then
  readonly GREEN=$(tput setaf 2)
  readonly YELLOW=$(tput setaf 3)
  readonly BLUE=$(tput setaf 4)
  readonly RESET=$(tput sgr0)
else
  readonly GREEN=""
  readonly YELLOW=""
  readonly BLUE=""
  readonly RESET=""
fi
```
with:
```bash
if command -v tput >/dev/null 2>&1 && [[ -t 1 ]]; then
  GREEN=$(tput setaf 2)
  YELLOW=$(tput setaf 3)
  BLUE=$(tput setaf 4)
  RESET=$(tput sgr0)
else
  GREEN=""
  YELLOW=""
  BLUE=""
  RESET=""
fi
readonly GREEN YELLOW BLUE RESET
```

Line 49 (in `get_time_message`) — replace:
```bash
  local hour=$(date +%H)
```
with:
```bash
  local hour
  hour=$(date +%H)
```

Line 86 (in `show_status`) — replace:
```bash
  local state=$(get_clock_state)
```
with:
```bash
  local state
  state=$(get_clock_state)
```

Line 96 (in `toggle_clock`) — replace:
```bash
  local current_state=$(get_clock_state)
```
with:
```bash
  local current_state
  current_state=$(get_clock_state)
```

- [ ] **Step 3: Verify clean**

Run: `cd $WT && shellcheck -S warning bin/cantsleep && echo CLEAN`
Expected: `CLEAN` (no output before it).
Run: `cd $WT && bash -n bin/cantsleep && echo OK`
Expected: `OK`.

- [ ] **Step 4: Commit**

```bash
cd $WT
git add bin/cantsleep
git commit -m "bin: split declare/assign in cantsleep to clear SC2155 (BIN-04)"
```

---

### Task 5: BIN-04 — shebang-driven shellcheck gate (Make + CI)

**Files:**
- Create: `tests/lint-shell.sh`
- Modify: `Makefile` (`.lint-shell` target, ~194-199)
- Modify: `.github/workflows/ci.yml` (`shellcheck` job, ~14-21)

**Interfaces:**
- Produces: `tests/lint-shell.sh` — discovers shell scripts by shebang, excludes zsh + non-shell, runs `shellcheck -S warning`. Invoked by `make .lint-shell` and the CI `shellcheck` job. Exit 0 = clean, non-zero = findings.

- [ ] **Step 1: Create the discovery script**

Create `tests/lint-shell.sh`:

```bash
#!/usr/bin/env bash
# Discover shell scripts by shebang and shellcheck them.
#
# Policy (single source of truth for both `make .lint-shell` and CI):
#   - Included: files whose shebang is a POSIX sh / bash / dash / ksh interpreter.
#   - Excluded (zsh): ShellCheck cannot parse zsh (error SC1071). zsh scripts
#     (e.g. bin/nshift, bin/countdown, tests/*.zsh) are parsed separately by the
#     `zsh-syntax` CI job via `zsh -n`.
#   - Excluded (non-shell): files without a shell shebang are skipped by
#     discovery (e.g. bin/nightshift-helper.swift, install/*.toml).
#
# Discovery roots: bin/, install/, tests/, .githooks/, and repo-root *.sh.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$REPO_ROOT"

# Return 0 if $1's first line is a supported (non-zsh) shell shebang.
is_shell_shebang() {
  local first
  IFS= read -r first < "$1" 2>/dev/null || return 1
  [[ "$first" == '#!'* ]] || return 1
  case "$first" in
    *zsh*) return 1 ;;
  esac
  [[ "$first" =~ (^|[/[:space:]])(sh|bash|dash|ksh)([[:space:]]|$) ]]
}

targets=()
while IFS= read -r f; do
  [ -f "$f" ] || continue
  if is_shell_shebang "$f"; then
    targets+=("$f")
  fi
done < <(ls -1 bin/* install/* tests/* .githooks/* ./*.sh 2>/dev/null | sort -u)

if [ "${#targets[@]}" -eq 0 ]; then
  echo "lint-shell: no shell scripts discovered" >&2
  exit 1
fi

echo "lint-shell: checking ${#targets[@]} script(s):"
printf '  %s\n' "${targets[@]}"
shellcheck -S warning "${targets[@]}"
echo "lint-shell: OK"
```

Then make it executable:

```bash
cd $WT && chmod +x tests/lint-shell.sh
```

- [ ] **Step 2: Verify discovery + gate pass**

Run: `cd $WT && tests/lint-shell.sh`
Expected: Lists the discovered scripts and prints `lint-shell: OK`. The list MUST include `bin/cantsleep`, `bin/confirm`, `bin/osx-clock-toggle`, `bin/lnclean`, `bin/mkx`, `bin/dotfiles`, `bootstrap.sh`, `install/*.sh`, `tests/*.sh` (incl. `tests/lint-shell.sh` itself), and the three `.githooks/*` scripts. It MUST NOT include `bin/nshift`, `bin/countdown`, `bin/nightshift-helper.swift`, or any `tests/*.zsh`.

If it fails on `tests/lint-shell.sh` itself or any script, fix the finding before proceeding (the gate must be green).

- [ ] **Step 3: Point the Makefile target at the script**

In `Makefile`, replace the `.lint-shell` target (currently lines ~194-199):

```make
.lint-shell:
	@if command -v shellcheck >/dev/null 2>&1; then \
		shellcheck -S warning bootstrap.sh install/*.sh bin/dotfiles tests/*.sh .githooks/setup.sh .githooks/post-merge .githooks/post-checkout; \
	else \
		echo "shellcheck not installed"; \
	fi
```

with:

```make
.lint-shell:
	@if command -v shellcheck >/dev/null 2>&1; then \
		tests/lint-shell.sh; \
	else \
		echo "shellcheck not installed"; \
	fi
```

- [ ] **Step 4: Point CI at the script**

In `.github/workflows/ci.yml`, replace the `shellcheck` job step (lines ~18-21):

```yaml
      - name: shellcheck (warning severity)
        run: |
          shellcheck -S warning bootstrap.sh install/*.sh bin/dotfiles tests/*.sh \
            .githooks/setup.sh .githooks/post-merge .githooks/post-checkout
```

with:

```yaml
      - name: shellcheck (shebang-discovered, warning severity)
        run: tests/lint-shell.sh
```

- [ ] **Step 5: Verify Make target and YAML**

Run: `cd $WT && make .lint-shell`
Expected: same discovery listing + `lint-shell: OK`.
Run: `cd $WT && zsh -n config/zsh/rc.d/00-platform.zsh 2>/dev/null; python3 -c 'import sys,yaml; yaml.safe_load(open(".github/workflows/ci.yml"))' 2>/dev/null && echo "YAML OK" || echo "YAML check skipped (no pyyaml)"`
Expected: `YAML OK` or the skip note (don't fail the task on a missing pyyaml).

- [ ] **Step 6: Commit**

```bash
cd $WT
git add tests/lint-shell.sh Makefile .github/workflows/ci.yml
git commit -m "ci: shebang-driven shellcheck discovery for all shell scripts (BIN-04)"
```

---

### Task 6: KITTY-02 — move remote-control socket off world-writable `/tmp`

**Files:**
- Modify: `config/kitty/kitty.conf:45-48`

**Interfaces:** none (kitty config).

- [ ] **Step 1: Edit the socket path**

In `config/kitty/kitty.conf`, replace:

```
# Remote control (required by smart-splits.nvim)
allow_remote_control yes
# {kitty_pid} keeps sockets unique so multiple instances don't collide
listen_on unix:/tmp/mykitty-{kitty_pid}
```

with:

```
# Remote control (required by smart-splits.nvim)
allow_remote_control yes
# {kitty_pid} keeps sockets unique so multiple instances don't collide.
# A relative path is resolved by kitty under the per-user temp dir (owned,
# mode 0700 on macOS) instead of shared, world-writable /tmp. This avoids
# depending on ${XDG_RUNTIME_DIR}, which a macOS GUI launch does not inherit.
listen_on unix:kitty-{kitty_pid}
```

- [ ] **Step 2: Sanity-check the change**

Run: `cd $WT && grep -n "listen_on" config/kitty/kitty.conf`
Expected: `listen_on unix:kitty-{kitty_pid}` (no `/tmp/`).

Note: this is GUI/kitty config with no automated test. Manual verification (documented, not part of `make test`): after `dotfiles sync`, in a running kitty confirm `kitten @ ls` works and `lsof -p $KITTY_PID | grep kitty-` shows the socket under `$TMPDIR`, not `/tmp`.

- [ ] **Step 3: Commit**

```bash
cd $WT
git add config/kitty/kitty.conf
git commit -m "kitty: use owned temp-dir socket for remote control (KITTY-02)"
```

---

### Task 7: Full-suite verification

**Files:** none (verification only).

- [ ] **Step 1: Run the whole test suite**

Run: `cd $WT && make test`
Expected: all suites pass, including `tests/test-bin-helpers.sh` (`Results: N passed, 0 failed`). If any fail, fix before proceeding — do not mark review entries Resolved on a red suite.

- [ ] **Step 2: Run the shell lint gate**

Run: `cd $WT && tests/lint-shell.sh`
Expected: `lint-shell: OK`.

- [ ] **Step 3: Parse-check zsh scripts (must not regress)**

Run: `cd $WT && zsh -n bin/nshift && zsh -n bin/countdown && echo "zsh OK"`
Expected: `zsh OK`.

- [ ] **Step 4: Confirm CLI-01 is already resolved (verify only)**

Run: `cd $WT && HOME=/tmp/cli01verify ./bin/dotfiles boguscommand >/dev/null 2>&1; echo "exit=$?"`
Expected: `exit=2`.
Run: `cd $WT && grep -n "unknown command exits with usage error" tests/test-uninstall.sh`
Expected: a match (the assertion already exists). No code change for CLI-01.

---

### Task 8: Mark review entries Resolved

**Files:**
- Modify: `docs/REVIEW-2026-07-14.md` (entries CLI-01, BIN-01, BIN-02, BIN-03, BIN-04, KITTY-02, TEST-05)

**Interfaces:** none (documentation).

- [ ] **Step 1: Collect the fixing commit hashes**

Run: `cd $WT && git log --oneline -8`
Note the short hashes for the BIN-01, BIN-02, BIN-03, BIN-04-cantsleep, BIN-04-ci, and KITTY-02 commits. Use them verbatim in the Resolved lines below (replace each `<hash-...>`).

- [ ] **Step 2: Edit each review entry in the existing style**

For each entry, insert a `- Resolved:` bullet directly under the `- Severity/status:` line and update the status to `Resolved`, matching the existing resolved-entry format in the file (see VALIDATE-01 / DOC-02 for the exact wording pattern). Concretely:

- **CLI-01** (`### CLI-01 — Unknown management commands exit successfully`): change title to `... — Resolved` and add:
  `- Resolved: 2026-07-14 — already fixed in the reviewed tree: usage() exits with its argument and main calls usage 2 for unknown commands; asserted by tests/test-uninstall.sh ("unknown command exits with usage error").`
- **BIN-01** (`### BIN-01 — confirm loops forever on EOF`): title `... — Resolved`; add:
  `- Resolved: 2026-07-14 by <hash-bin01> — confirm treats a failed read (EOF/closed stdin) as a decline; covered by tests/test-bin-helpers.sh.`
- **BIN-02** (`### BIN-02 — nshift for validates duration after arithmetic evaluation`): title `... — Resolved`; add:
  `- Resolved: 2026-07-14 by <hash-bin02> — validates positive-integer hours before any arithmetic (no bc); timer PID state moved to an owned ${XDG_RUNTIME_DIR}/nshift dir with argv-marker process-identity verification before kill; covered by tests/test-bin-helpers.sh.`
- **BIN-03** (`### BIN-03 — Duplicate clock toggle has weaker state handling`): title `... — Resolved`; add:
  `- Resolved: 2026-07-14 by <hash-bin03> — osx-clock-toggle is now a thin wrapper delegating the clock to cantsleep and Night Shift to nshift toggle, removing the grep '1' partial match and int/bool mismatch; covered by tests/test-bin-helpers.sh.`
- **BIN-04** (`### BIN-04 — Smaller executable scripts are outside the normal ShellCheck gate`): title `... — Resolved`; add:
  `- Resolved: 2026-07-14 by <hash-bin04-cantsleep> and <hash-bin04-ci> — cantsleep SC2155 warnings fixed; tests/lint-shell.sh discovers shell scripts by shebang (excluding zsh and non-shell) and is used by both make .lint-shell and the CI shellcheck job.`
- **KITTY-02** (`### KITTY-02 — Remote-control socket should use the runtime directory`): title `... — Resolved`; add:
  `- Resolved: 2026-07-14 by <hash-kitty02> — listen_on uses a relative socket path resolved under the per-user temp dir (owned) instead of shared /tmp, without depending on ${XDG_RUNTIME_DIR} which a macOS GUI launch does not inherit.`
- **TEST-05** (`### TEST-05 — Smaller scripts lack automated lint and edge-case tests`): title `... — Resolved`; add:
  `- Resolved: 2026-07-14 by <hash-bin01>, <hash-bin02>, <hash-bin03>, <hash-bin04-ci> — tests/test-bin-helpers.sh covers confirm EOF, nshift duration validation and PID-state safety, and osx-clock-toggle delegation; tests/lint-shell.sh adds the shebang-driven lint gate.`

- [ ] **Step 3: Verify the doc edits**

Run: `cd $WT && grep -nE "^### (CLI-01|BIN-0[1-4]|KITTY-02|TEST-05).*Resolved" docs/REVIEW-2026-07-14.md`
Expected: 7 matching headings.

- [ ] **Step 4: Commit**

```bash
cd $WT
git add docs/REVIEW-2026-07-14.md
git commit -m "docs: mark CLI-01, BIN-01..04, KITTY-02, TEST-05 resolved"
```

---

## Self-Review

**Spec coverage:**
- BIN-01 → Task 1. BIN-02 → Task 2. BIN-03 → Task 3. BIN-04 → Tasks 4 (cantsleep) + 5 (gate). KITTY-02 → Task 6. TEST-05 → Tasks 1/2/3 (edge tests) + 5 (lint). CLI-01 → Task 7 (verify) + Task 8 (mark Resolved). Review-doc updates → Task 8. Full-suite verification → Task 7. All spec sections covered.

**Placeholder scan:** The only intentional fill-ins are the six `<hash-...>` commit hashes in Task 8, which are concrete values collected in Task 8 Step 1 from `git log`. No vague "add error handling"/"TBD" steps; every code step shows complete code.

**Type/name consistency:** `TIMER_MARKER`, `NSHIFT_RUNTIME_DIR`, `TIMER_PID_FILE`, `ensure_runtime_dir`, `pid_is_our_timer` are defined in Task 2 and used consistently in `cancel_timer`/`enable_for_duration`/`show_status` within the same task. `run_capped` (Task 1) sets `CAP_OUT`/`CAP_RC`, used in Task 1. `tests/lint-shell.sh` is created in Task 5 and referenced by the Makefile/CI edits in the same task and by Task 7's verification.
