#!/usr/bin/env bash
# Regression tests for Zsh startup state. Run via `make test`.

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$REPO_ROOT" || exit 1

# shellcheck source=tests/lib.sh
source "$REPO_ROOT/tests/lib.sh"

if ! command -v zsh >/dev/null 2>&1; then
  echo "skip: zsh is not installed"
  exit 0
fi

mode_of() {
  stat -f '%Lp' "$1" 2>/dev/null || stat -c '%a' "$1"
}

tmp_home="$(mktemp -d)"
tmp_runtime_root="$(mktemp -d)"
trap 'rm -rf "$tmp_home" "$tmp_runtime_root"' EXIT

HOME="$tmp_home" ./bootstrap.sh --sync --profile minimal >/dev/null

echo "== fresh cache and runtime directories =="
startup_out="$(
  env -u XDG_RUNTIME_DIR HOME="$tmp_home" TMPDIR="$tmp_runtime_root/" \
    XDG_DATA_HOME="$tmp_home/.local/share" XDG_CONFIG_HOME="$tmp_home/.config" \
    XDG_STATE_HOME="$tmp_home/.local/state" XDG_CACHE_HOME="$tmp_home/.cache" zsh -dfc '
    source "$HOME/.zshenv"
    source "$ZDOTDIR/lib/platform.zsh"
    source "$ZDOTDIR/rc.d/30-completions.zsh"
    print -r -- "$XDG_RUNTIME_DIR"
  '
)"
runtime_dir="$(tail -n 1 <<<"$startup_out")"
expected_runtime_dir="$tmp_runtime_root/run-$(id -u)"

assert_eq "uses a UID-specific runtime directory" "$expected_runtime_dir" "$runtime_dir"
assert_eq "runtime directory mode is private" "700" "$(mode_of "$runtime_dir")"
assert_eq "completion cache directory is created" "yes" \
  "$([[ -d "$tmp_home/.cache/zsh" ]] && echo yes || echo no)"
assert_eq "completion cache directory mode is private" "700" \
  "$(mode_of "$tmp_home/.cache/zsh")"

echo "== existing runtime directory =="
existing_runtime="$tmp_runtime_root/existing-runtime"
mkdir -m 700 "$existing_runtime"
existing_out="$(
  HOME="$tmp_home" XDG_RUNTIME_DIR="$existing_runtime" \
    XDG_DATA_HOME="$tmp_home/.local/share" XDG_CONFIG_HOME="$tmp_home/.config" \
    XDG_STATE_HOME="$tmp_home/.local/state" XDG_CACHE_HOME="$tmp_home/.cache" zsh -dfc '
    source "$HOME/.zshenv"
    print -r -- "$XDG_RUNTIME_DIR"
  '
)"
assert_eq "preserves a supplied runtime directory" "$existing_runtime" "$existing_out"

echo "== repository discovery =="
dotdir_out="$(
  HOME="$tmp_home" XDG_DATA_HOME="$tmp_home/.local/share" \
    XDG_CONFIG_HOME="$tmp_home/.config" XDG_STATE_HOME="$tmp_home/.local/state" \
    XDG_CACHE_HOME="$tmp_home/.cache" zsh -dfc '
    source "$HOME/.zshenv"
    source "$ZDOTDIR/.zprofile"
    source "$ZDOTDIR/lib/platform.zsh"
    source "$ZDOTDIR/rc.d/20-exports.zsh"
    print -r -- "$DOTDIR"
  '
)"
assert_eq "derives DOTDIR from the linked CLI" "$REPO_ROOT" "$dotdir_out"

echo
echo "Zsh startup tests: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]
