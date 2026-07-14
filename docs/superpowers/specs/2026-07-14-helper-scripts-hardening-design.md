# Helper scripts hardening — design spec

Date: 2026-07-14
Branch: `helper-scripts-hardening` (off `main`)
Review source: `docs/REVIEW-2026-07-14.md` (BIN-01..04, KITTY-02, TEST-05, CLI-01)

## Goal

Harden the smaller `bin/` helper executables and close the CI lint / edge-test
gaps around them. Localized robustness fixes plus a lint and test-coverage
expansion. No behavior change to unrelated scripts.

## Scope

In scope: BIN-01, BIN-02, BIN-03, BIN-04, KITTY-02, TEST-05, and verifying
CLI-01. Out of scope: everything else in the review (Phase 2 packages, docs,
Neovim, ZSH items — the ZSH-04..09 work is already merged to `main`).

## Constraints

- Never edit `~/.config/` directly; edit repo sources under `config/` / `bin/`.
- Zsh files are parsed (`zsh -n`), not shellchecked as bash. The existing bash
  shellcheck gate must not regress.
- Every behavior change gets a test in the existing harness (`tests/lib.sh`,
  `assert_eq` / `assert_contains`; drive scripts with controlled stdin/args in a
  subshell). `make test` must stay green on both macOS and Ubuntu CI.
- Do not commit or push unless asked.
- Mark addressed review entries Resolved with the fixing commit, existing style.

---

## BIN-01 — `confirm` loops forever on EOF

`bin/confirm` (`#!/bin/sh`) loops on `read -r yn` with no handling of read
failure. With closed stdin, `read` returns non-zero every iteration and the
loop reprints the prompt / "Please answer yes or no." forever.

**Fix:** treat a failed `read` (EOF / closed stdin) as a decline. In the read
loop, `read -r yn || { printf '\n'; exit 1; }`. Interactive behavior is
unchanged (a real `y`/`n` still works); a non-interactive caller now declines
deterministically with exit status 1 instead of spinning.

**Test (TEST-05):** run `printf '' | confirm` (and `confirm </dev/null`) in a
subshell; assert exit status 1 and that the "Please answer yes or no." error
does not repeat (bounded output). Interactive-path sanity: `printf 'y\n'`
exits 0, `printf 'n\n'` exits 1.

---

## BIN-02 — `nshift for` duration validation, `bc` removal, PID-state safety

`bin/nshift` (`#!/bin/zsh`) currently:
- computes `seconds=$((hours * 3600))` *before* validating `hours`;
- validates using `bc -l` (`echo "$hours <= 0" | bc -l`) — `bc` is neither
  checked for nor installed;
- stores the timer PID at a predictable `${TMPDIR:-/tmp}/nshift-timer.pid` and
  only checks `kill -0 "$pid"` (process existence), which can match an unrelated
  reused PID.

**Grammar decision:** `for [HOURS]` accepts **positive integers only**
(`^[0-9]+$`, and not all-zeros). Decimals/negatives/junk are rejected with a
clear message. Rationale: integer hours keep `$((hours * 3600))` pure-integer
(no `bc`, no float), and `date -v+${seconds}S` needs integer seconds — the
decimal path is already partially broken today (the auto-disable time display),
so this removes a broken path rather than a used feature.

**Fixes:**
1. In `enable_for_duration`, validate the raw `hours` string *first*, before any
   arithmetic or side effects:
   - reject if it does not match `^[0-9]+$`;
   - reject if it is zero (`^0+$`);
   - only then compute `seconds`.
   No `bc` anywhere.
2. Timer PID state moves to an owned runtime directory:
   `NSHIFT_RUNTIME_DIR="${XDG_RUNTIME_DIR:-${TMPDIR:-/tmp}}/nshift"`, created
   `mkdir -p` then `chmod 700`. `TIMER_PID_FILE="$NSHIFT_RUNTIME_DIR/timer.pid"`.
   nshift runs via `#!/bin/zsh`, so `zshenv` (symlinked to `~/.zshenv`) has
   already established `XDG_RUNTIME_DIR` (UID-private, mode 0700); the
   `TMPDIR`/`/tmp` fallbacks keep it working if run under an odd environment.
3. Process-identity verification before killing a recorded PID: a helper
   `pid_is_our_timer <pid>` confirms the process exists **and** its command line
   (`ps -o command= -p <pid>`) matches our timer signature (it runs
   `nightshift-helper.swift` / our `sleep`+swift subshell). `cancel_timer`,
   `show_status`, and the background timer only act on a PID that passes this
   check; a stale/reused PID is treated as "no active timer" and the pid file is
   cleaned up. This prevents nshift from killing an unrelated process that
   happens to have inherited the old PID.

**Tests (TEST-05):** drive `zsh bin/nshift` with a stubbed environment so it runs
on Linux CI — a fake `uname` (returns `Darwin`), a fake `swift`, and the real
helper file present (or a stub the script accepts). Assert:
- `for 0`, `for -1`, `for 0.5`, `for abc` → exit 1, message "Invalid duration",
  and **no** timer pid file created and **no** `swift ... on` invocation
  (validation happens before side effects);
- `for 2` (with fully stubbed helper) → accepted;
- a pid file containing a live-but-foreign PID (e.g. a `sleep 300` whose command
  does not match the timer signature) is treated as no active timer and is not
  killed. If reliably stubbing the whole helper chain proves brittle, fall back
  to unit-testing the extracted validation via `zsh -c` sourcing the predicate
  functions, and document the boundary in the test file.

---

## BIN-03 — `osx-clock-toggle` duplicate → composite wind-down wrapper

`bin/osx-clock-toggle` (`#!/bin/sh`) duplicates `bin/cantsleep`'s clock toggle
with weaker state handling: `grep -q '1'` matches values like `10`, and it
writes `IsAnalog -int` while `cantsleep` uses `-bool` for the same key. It is
unreferenced anywhere except the review docs.

**Resolution (user-directed):** keep the command name — the user uses it as a
CLI tool — but make it a thin **composite wrapper** that is the single
"wind-down" entry point:
- toggles the menu-bar clock by delegating to `cantsleep` (removes the
  `grep '1'` bug and the int/bool mismatch; one source of truth);
- toggles Night Shift by delegating to `nshift toggle`.

Both siblings are resolved relative to the script's own directory so it works
regardless of `PATH` ordering. Argument forwarding:
- no args → `cantsleep` + `nshift toggle`;
- `--quiet`/`-q` → `cantsleep --quiet` + `nshift -q`;
- `--status`/`-s` → `cantsleep --status` + `nshift status` (shows both);
- `--help`/`-h` → short help describing the combo.

Toggles are **independent** (clock toggles, Night Shift toggles) — no shared
state coupling. Documented as such; if the two ever start out of sync a single
extra invocation resyncs them. `#!/bin/sh`, macOS-only (both delegates already
enforce Darwin).

**Test (TEST-05):** put stub `cantsleep` and `nshift` on a fake `PATH` beside a
copy of the wrapper (or invoke via a temp dir) that record their argv to a log;
assert that a bare invocation calls `cantsleep` once and `nshift toggle` once,
that `--quiet` forwards `--quiet`/`-q`, and that `--status` calls both status
paths. Runs on Linux CI because the delegates are stubbed.

---

## BIN-04 — shebang-driven shellcheck gate + fix `cantsleep`

The gate (`Makefile` `.lint-shell`, `.github/workflows/ci.yml` `shellcheck`
job) hardcodes `bootstrap.sh install/*.sh bin/dotfiles tests/*.sh` plus hooks —
it misses the other `bin/` executables. `bin/cantsleep` has 6 real `SC2155`
warnings ("declare and assign separately").

**Fixes:**
1. Fix `cantsleep` SC2155: split `readonly NAME=$(...)` / `local x=$(...)` into a
   bare declaration followed by assignment (`readonly SCRIPT_NAME`;
   `SCRIPT_NAME=$(basename "$0")` — or restructure the color block). Verify
   `shellcheck -S warning bin/cantsleep` is clean.
2. Add `tests/lint-shell.sh` — the single source of truth for discovery and the
   exclusion policy:
   - discover candidate scripts by shebang: iterate tracked files under
     `bin/`, `install/`, `tests/`, repo-root `*.sh`, and `.githooks/`, selecting
     files whose first line matches a POSIX-sh/bash/dash/ksh shebang
     (`#!.*/(ba|da|k)?sh` and `env sh|bash|...`);
   - **exclude** files whose shebang is zsh (`bin/nshift` `#!/bin/zsh`,
     `bin/countdown` `#!/usr/bin/env zsh`) — shellcheck errors on zsh (SC1071);
     zsh is parsed separately by the `zsh-syntax` CI job;
   - **exclude** non-shell files (e.g. `bin/nightshift-helper.swift`) — no shell
     shebang, so shebang discovery already skips them; documented for clarity;
   - run `shellcheck -S warning` over the discovered set; exit non-zero on
     findings. The exclusion rationale lives in a comment block at the top of the
     script.
3. `Makefile` `.lint-shell` calls `tests/lint-shell.sh` (guarded on
   `command -v shellcheck`). The CI `shellcheck` job runs `tests/lint-shell.sh`.
   Discovery + exclusions defined once; no Makefile/CI drift.

**Note:** the script is itself a shell script under `tests/`, so it lints
itself. Its own shellcheck cleanliness is part of the gate.

---

## KITTY-02 — remote-control socket off world-writable `/tmp`

`config/kitty/kitty.conf:48` sets `listen_on unix:/tmp/mykitty-{kitty_pid}`.
`/tmp` is world-writable/shared; `{kitty_pid}` prevents collisions but not the
weak ownership boundary.

**Decision:** use a **relative** socket path: `listen_on unix:kitty-{kitty_pid}`.
kitty expands environment variables in `listen_on` and **resolves relative paths
from the temporary directory** (per kitty docs). On macOS `TMPDIR` is the
per-user, mode-0700 `/var/folders/<hash>/T/` — an owned, private location. This
achieves the review's "owned runtime directory" intent while being robust to how
kitty is actually launched: as a macOS GUI app it does **not** inherit
`XDG_RUNTIME_DIR` from the shell, so a literal `unix:${XDG_RUNTIME_DIR}/...`
would expand to a broken `/kitty-...` and silently disable remote control
(breaking `smart-splits.nvim`). The relative form has no env dependency.

**Verification (manual, documented):** this is GUI/kitty config with no unit
test. After sync, confirm in a running kitty that
`kitten @ ls` works and the socket lives under `$TMPDIR`, not `/tmp`. Called out
because it cannot be covered by the bash harness.

---

## CLI-01 — unknown management commands (verify only)

Already resolved in the reviewed tree: `bin/dotfiles` `usage()` takes an exit
code (`local exit_code="${1:-0}"`) and ends with `exit "$exit_code"`; `main`'s
`*)` branch prints "Unknown command" then calls `usage 2`. Empirically
`dotfiles boguscommand` exits 2, and `tests/test-uninstall.sh:349-350` already
asserts "unknown command exits with usage error" == 2 and the message. Action:
mark CLI-01 Resolved in the review doc; no code change.

---

## TEST-05 — test file organization

New tests live in `tests/test-bin-helpers.sh` (auto-discovered by
`make test`'s `tests/test-*.sh` loop; run under bash). It follows the harness:
sets `REPO_ROOT`, sources `tests/lib.sh`, uses `assert_eq` / `assert_contains`,
`make_fake_bin` for PATH stubs, and `mktemp -d` sandboxes. Sections: confirm EOF
(BIN-01), nshift validation + PID-state safety (BIN-02), osx-clock-toggle
delegation (BIN-03). All sections must pass on both macOS and Ubuntu CI, so
macOS-only delegates are exercised through stubs, never the real `defaults`/
`swift`.

## Definition of done

- BIN-01..04 and KITTY-02 fixed as above; CLI-01 verified.
- `tests/test-bin-helpers.sh` covers the changed behavior; `make test` green.
- `tests/lint-shell.sh` green; `shellcheck` CI job green; zsh parse job green.
- Review-doc entries marked Resolved with the fixing commit(s), existing style.
