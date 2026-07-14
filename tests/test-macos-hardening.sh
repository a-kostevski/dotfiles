#!/usr/bin/env bash
# Focused regression tests for config/macos/harden.zsh.

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
export REPO_ROOT
# shellcheck source=tests/lib.sh
source "$REPO_ROOT/tests/lib.sh"

if ! command -v zsh >/dev/null 2>&1; then
  echo "skip: zsh is required to test macOS hardening"
  exit 0
fi

echo "== macOS hardening safeguards =="
tmp_hardening="$(mktemp -d)"

mkdir -p "$tmp_hardening/bin" "$tmp_hardening/home" "$tmp_hardening/state"
printf '#!/usr/bin/env bash\nprintf defaults-state\n' >"$tmp_hardening/bin/defaults"
printf '#!/usr/bin/env bash\nprintf pmset-state\n' >"$tmp_hardening/bin/pmset"
chmod +x "$tmp_hardening/bin/defaults" "$tmp_hardening/bin/pmset"

export TEST_HOME="$tmp_hardening/home"
export TEST_STATE="$tmp_hardening/state"
export TEST_BIN="$tmp_hardening/bin"
hardening_out="$(zsh "$REPO_ROOT/tests/macos-hardening-regression.zsh" 2>&1)"
hardening_rc=$?
assert_eq "backup fixture exits cleanly" "0" "$hardening_rc"
assert_contains "backup succeeds" "backup_status=0" "$hardening_out"
assert_contains "backup is user-owned state, not /var/root" "backup_dir=$tmp_hardening/state/dotfiles/macos-hardening/" "$hardening_out"
assert_contains "backup preserves defaults output" "backup_defaults=defaults-state" "$hardening_out"
assert_contains "backup preserves pmset output" "backup_pmset=pmset-state" "$hardening_out"
assert_contains "backup directory is private" "backup_mode=700" "$hardening_out"
assert_contains "backup files are private" "backup_file_mode=600" "$hardening_out"
assert_contains "failed command returns non-zero" "command_status=1" "$hardening_out"
assert_contains "backup failure exits non-zero" "backup_failure_status=1" "$hardening_out"
assert_contains "backup failure prevents later phases" "backup_failure_calls=backup" "$hardening_out"
assert_contains "failed hardening exits non-zero" "hardening_status=1" "$hardening_out"
assert_contains "hardening stops at first failed phase" "calls=backup,updates" "$hardening_out"

rm -rf "$tmp_hardening"

echo
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
