#!/usr/bin/env bash
# Regression tests for the bootstrap/profile machinery.
# Run via `make test` or directly: bash tests/test-bootstrap.sh

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

PASS=0
FAIL=0

assert_eq() {
  local desc="$1" expected="$2" actual="$3"
  if [[ "$expected" == "$actual" ]]; then
    PASS=$((PASS + 1))
    echo "  ok: $desc"
  else
    FAIL=$((FAIL + 1))
    echo "  FAIL: $desc"
    echo "    expected: $(printf '%q' "$expected")"
    echo "    actual:   $(printf '%q' "$actual")"
  fi
}

assert_contains() {
  local desc="$1" needle="$2" haystack="$3"
  if [[ "$haystack" == *"$needle"* ]]; then
    PASS=$((PASS + 1))
    echo "  ok: $desc"
  else
    FAIL=$((FAIL + 1))
    echo "  FAIL: $desc (missing: $needle)"
  fi
}

echo "== get_config_list =="
# shellcheck source=/dev/null
source "$REPO_ROOT/install/lib.sh"
# shellcheck source=/dev/null
source "$REPO_ROOT/install/profiles.sh"

# Named profiles must emit one config per line (regression: a quoting bug
# once made every named profile emit a single space-joined line, which the
# symlink loop silently skipped — profiles installed nothing)
assert_eq "minimal emits one config per line" \
  "$(printf 'git\nzsh\ntmux')" \
  "$(get_config_list minimal)"

assert_eq "standard extends minimal" \
  "$(printf 'git\nzsh\ntmux\nnvim\nbat\npython\nripgrep')" \
  "$(get_config_list standard)"

full_macos="$(get_config_list full macos)"
assert_contains "full/macos includes base configs" "nvim" "$full_macos"
assert_contains "full/macos includes karabiner" "karabiner" "$full_macos"
assert_contains "full/macos includes kitty" "kitty" "$full_macos"

full_ubuntu="$(get_config_list full ubuntu)"
assert_eq "full/ubuntu has no macOS extras" "" "$(grep -E 'karabiner|kitty|homebrew' <<<"$full_ubuntu" || true)"

if get_config_list bogus >/dev/null 2>&1; then
  FAIL=$((FAIL + 1))
  echo "  FAIL: unknown profile should return non-zero"
else
  PASS=$((PASS + 1))
  echo "  ok: unknown profile returns non-zero"
fi

# Every config named in a profile must exist as a directory in config/
echo "== profile configs exist =="
missing=""
for profile in minimal standard full; do
  while IFS= read -r cfg; do
    # clang-format is a single file, tracked as a known exception
    [[ "$cfg" == "clang-format" ]] && continue
    [[ -d "$REPO_ROOT/config/$cfg" ]] || missing="$missing $profile:$cfg"
  done < <(get_config_list "$profile" macos)
done
assert_eq "all profile configs exist in config/" "" "$missing"

echo "== bootstrap dry run =="
dry_out="$(./bootstrap.sh --profile minimal --dry-run --skip-install 2>&1)"
assert_contains "dry run processes git" "Processing git configuration" "$dry_out"
assert_contains "dry run processes zsh" "Processing zsh configuration" "$dry_out"
assert_contains "dry run processes tmux" "Processing tmux configuration" "$dry_out"
assert_eq "dry run emits no [DEBUG] noise" "" "$(grep -F '[DEBUG]' <<<"$dry_out" || true)"

echo
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
