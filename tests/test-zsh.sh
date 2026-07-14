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

get_file_mtime_host() { stat -f '%m' "$1" 2>/dev/null || stat -c '%Y' "$1"; }

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

echo "== ZSH-05 aliases =="
alias_out="$(
  HOME="$tmp_home" XDG_DATA_HOME="$tmp_home/.local/share" \
    XDG_CONFIG_HOME="$tmp_home/.config" XDG_STATE_HOME="$tmp_home/.local/state" \
    XDG_CACHE_HOME="$tmp_home/.cache" zsh -dfc '
    source "$HOME/.zshenv"
    source "$ZDOTDIR/lib/platform.zsh"
    source "$ZDOTDIR/rc.d/60-aliases.zsh" 2>/dev/null
    print -r -- "macos_config=$(whence -w macos_config 2>/dev/null)"
    print -r -- "clconfig=$(whence -w clconfig 2>/dev/null)"
  '
)"
assert_eq "macos_config alias is removed" "macos_config=macos_config: none" \
  "$(grep '^macos_config=' <<<"$alias_out")"
assert_eq "clconfig is a function" "clconfig=clconfig: function" \
  "$(grep '^clconfig=' <<<"$alias_out")"
assert_eq "geoip uses https" "yes" \
  "$([[ "$(grep -E '^alias geoip=' "$REPO_ROOT/config/zsh/rc.d/60-aliases.zsh")" == *https://* ]] && echo yes || echo no)"
assert_eq "publicip4 avoids http" "yes" \
  "$(grep -E '^alias publicip4=' "$REPO_ROOT/config/zsh/rc.d/60-aliases.zsh" | grep -q 'http://' && echo no || echo yes)"

echo "== ZSH-04 locale =="
locale_out="$(
  env -u LC_ALL -u LANG HOME="$tmp_home" XDG_CONFIG_HOME="$tmp_home/.config" \
    XDG_DATA_HOME="$tmp_home/.local/share" XDG_STATE_HOME="$tmp_home/.local/state" \
    XDG_CACHE_HOME="$tmp_home/.cache" zsh -dfc '
    source "$HOME/.zshenv"
    print -r -- "LC_ALL=[${LC_ALL-unset}]"
    if [[ -n "$LANG" ]]; then
      locale -a 2>/dev/null | grep -qxF "$LANG" && print -r -- "LANG_OK=yes" || print -r -- "LANG_OK=no"
    else
      print -r -- "LANG_OK=yes"
    fi
  '
)"
assert_eq "LC_ALL is not exported globally" "LC_ALL=[unset]" "$(grep '^LC_ALL=' <<<"$locale_out")"
assert_eq "LANG is an available locale (or unset)" "LANG_OK=yes" "$(grep '^LANG_OK=' <<<"$locale_out")"

echo "== ZSH-09 command_exists + dedup =="
ce_out="$(
  HOME="$tmp_home" FAKE_BIN="$tmp_runtime_root/fakebin" \
    XDG_CONFIG_HOME="$tmp_home/.config" XDG_DATA_HOME="$tmp_home/.local/share" \
    XDG_STATE_HOME="$tmp_home/.local/state" XDG_CACHE_HOME="$tmp_home/.cache" zsh -dfc '
    source "$HOME/.zshenv"
    source "$ZDOTDIR/lib/platform.zsh"
    command_exists zqxtool && print -r -- "before=found" || print -r -- "before=absent"
    mkdir -p "$FAKE_BIN"
    print -r -- "#!/bin/sh" > "$FAKE_BIN/zqxtool"; chmod +x "$FAKE_BIN/zqxtool"
    path=("$FAKE_BIN" $path); rehash
    command_exists zqxtool && print -r -- "after=found" || print -r -- "after=absent"
  '
)"
assert_eq "command_exists sees a newly installed command" "$(printf 'before=absent\nafter=found')" \
  "$(grep -E '^(before|after)=' <<<"$ce_out")"

dedup_out="$(
  HOME="$tmp_home" PLUSDIR="$tmp_runtime_root/a+b" \
    XDG_CONFIG_HOME="$tmp_home/.config" XDG_DATA_HOME="$tmp_home/.local/share" \
    XDG_STATE_HOME="$tmp_home/.local/state" XDG_CACHE_HOME="$tmp_home/.cache" zsh -dfc '
    source "$HOME/.zshenv"
    source "$ZDOTDIR/lib/platform.zsh"
    source "$ZDOTDIR/profile.d/10-path.zsh"
    source "$ZDOTDIR/profile.d/00-fpath.zsh"
    mkdir -p "$PLUSDIR"
    prepend_path "$PLUSDIR"; prepend_path "$PLUSDIR"
    append_fpath "$PLUSDIR"; append_fpath "$PLUSDIR"
    typeset -a mp mf; mp=(${(M)path:#$PLUSDIR}); mf=(${(M)fpath:#$PLUSDIR})
    print -r -- "path_count=${#mp}"
    print -r -- "fpath_count=${#mf}"
  '
)"
assert_eq "path dedups a regex-special dir exactly once" "path_count=1" "$(grep '^path_count=' <<<"$dedup_out")"
assert_eq "fpath dedups a regex-special dir exactly once" "fpath_count=1" "$(grep '^fpath_count=' <<<"$dedup_out")"

echo "== ZSH-07 completion cache =="
comp_err="$tmp_runtime_root/comp_err"
run_comp() {
  env -u HOMEBREW_PREFIX HOME="$tmp_home" XDG_CONFIG_HOME="$tmp_home/.config" \
    XDG_DATA_HOME="$tmp_home/.local/share" XDG_STATE_HOME="$tmp_home/.local/state" \
    XDG_CACHE_HOME="$tmp_home/.cache" zsh -dfc '
    source "$HOME/.zshenv"
    source "$ZDOTDIR/lib/platform.zsh"
    source "$ZDOTDIR/profile.d/00-fpath.zsh"
    source "$ZDOTDIR/rc.d/30-completions.zsh"
  ' 2>"$comp_err"
}
dump="$tmp_home/.cache/zsh/zcompdump"
run_comp
assert_eq "compdump created on first run" "yes" "$([[ -s "$dump" ]] && echo yes || echo no)"
mtime1="$(get_file_mtime_host "$dump")"
sleep 1; run_comp
mtime2="$(get_file_mtime_host "$dump")"
assert_eq "compdump kept when nothing changed" "$mtime1" "$mtime2"
touch -t 203012312359 "$tmp_home/.config/zsh/functions"
sleep 1; run_comp
mtime3="$(get_file_mtime_host "$dump")"
assert_eq "compdump regenerates when an fpath dir is newer" "yes" \
  "$([[ "$mtime3" != "$mtime2" ]] && echo yes || echo no)"
chmod g+w "$tmp_home/.config/zsh/functions"
run_comp
assert_eq "no insecure-directory warning with compinit -i" "" \
  "$(grep -i insecure "$comp_err" || true)"

echo "== ZSH-08 plugin lock =="
lock="$tmp_runtime_root/plugins.lock"
printf '# c\nzsh-users/zsh-autosuggestions abc123\nromkatv/zsh-defer def456\n' > "$lock"
locked_out="$(
  HOME="$tmp_home" ZPLUGIN_LOCK="$lock" XDG_CONFIG_HOME="$tmp_home/.config" \
    XDG_DATA_HOME="$tmp_home/.local/share" XDG_STATE_HOME="$tmp_home/.local/state" \
    XDG_CACHE_HOME="$tmp_home/.cache" zsh -dfc '
    source "$HOME/.zshenv"; source "$ZDOTDIR/lib/platform.zsh"
    source "$ZDOTDIR/rc.d/70-zsh-unplugged.zsh"
    print -r -- "hit=$(_plug_locked_rev zsh-users/zsh-autosuggestions)"
    _plug_locked_rev zsh-users/nope >/dev/null && print -r -- "miss=found" || print -r -- "miss=absent"
  '
)"
assert_eq "locked rev returns pinned sha" "hit=abc123" "$(grep '^hit=' <<<"$locked_out")"
assert_eq "locked rev misses unlisted repo" "miss=absent" "$(grep '^miss=' <<<"$locked_out")"

fake_git="$tmp_runtime_root/gitstub"
make_fake_bin "$fake_git" git '
case "$1" in
  clone) dest="${@: -1}"; mkdir -p "$dest"; echo "clone $dest" >>"$GIT_LOG"; : > "$dest/x.plugin.zsh" ;;
  -C) shift; d="$1"; shift; echo "-C $d $*" >>"$GIT_LOG"
      case "$1 $2" in
        "remote get-url") echo "https://github.com/zsh-users/zsh-autosuggestions.git" ;;
        "rev-parse HEAD") echo abc123def ;;
      esac ;;
esac
exit 0'
fetch_log="$tmp_runtime_root/git.log"; : > "$fetch_log"
plugdir="$tmp_runtime_root/plug/zsh-autosuggestions"
PATH="$fake_git:$PATH" GIT_LOG="$fetch_log" ZPLUGIN_LOCK="$lock" HOME="$tmp_home" \
  XDG_CONFIG_HOME="$tmp_home/.config" XDG_DATA_HOME="$tmp_home/.local/share" \
  XDG_STATE_HOME="$tmp_home/.local/state" XDG_CACHE_HOME="$tmp_home/.cache" zsh -dfc '
    source "$HOME/.zshenv"; source "$ZDOTDIR/lib/platform.zsh"
    source "$ZDOTDIR/rc.d/70-zsh-unplugged.zsh"
    _plug_fetch zsh-users/zsh-autosuggestions "'"$plugdir"'"
  '
assert_eq "pinned fetch checks out the locked sha" "yes" \
  "$(grep -q 'checkout -q abc123' "$fetch_log" && echo yes || echo no)"

wl_root="$tmp_runtime_root/wl"; mkdir -p "$wl_root/zsh-autosuggestions/.git"
out_lock="$tmp_runtime_root/out.lock"
PATH="$fake_git:$PATH" GIT_LOG="$fetch_log" ZPLUGINDIR="$wl_root" ZPLUGIN_LOCK="$out_lock" \
  HOME="$tmp_home" XDG_CONFIG_HOME="$tmp_home/.config" XDG_DATA_HOME="$tmp_home/.local/share" \
  XDG_STATE_HOME="$tmp_home/.local/state" XDG_CACHE_HOME="$tmp_home/.cache" zsh -dfc '
    source "$HOME/.zshenv"; source "$ZDOTDIR/lib/platform.zsh"
    source "$ZDOTDIR/rc.d/70-zsh-unplugged.zsh"
    _plug_write_lock
  ' >/dev/null
assert_eq "write_lock records owner/repo and sha" "yes" \
  "$(grep -q 'zsh-users/zsh-autosuggestions abc123def' "$out_lock" && echo yes || echo no)"
assert_eq "_plug_compile is removed" "0" \
  "$(grep -c '_plug_compile' "$REPO_ROOT/config/zsh/rc.d/70-zsh-unplugged.zsh")"

echo "== ZSH-06 fzf single init =="
fzf_dir="$tmp_runtime_root/fzfstub"
make_fake_bin "$fzf_dir" fzf '
if [ "$1" = "--zsh" ]; then echo "1" >> "$FZF_COUNT"; echo "# fzf init"; fi
exit 0'
git_dir="$tmp_runtime_root/gitstub2"
make_fake_bin "$git_dir" git '
if [ "$1" = "clone" ]; then dest="${@: -1}"; mkdir -p "$dest"; : > "$dest/x.plugin.zsh"; fi
exit 0'
fzf_count="$tmp_runtime_root/fzf_count"; : > "$fzf_count"
env -u KITTY_INSTALLATION_DIR HOME="$tmp_home" \
  XDG_CONFIG_HOME="$tmp_home/.config" XDG_DATA_HOME="$tmp_home/.local/share" \
  XDG_STATE_HOME="$tmp_home/.local/state" XDG_CACHE_HOME="$tmp_home/.cache" \
  FZF_COUNT="$fzf_count" ZPLUGINDIR="$tmp_runtime_root/fzfplug" \
  PATH="$fzf_dir:$git_dir:/usr/bin:/bin" zsh -dfc '
    source "$HOME/.zshenv"; source "$ZDOTDIR/lib/platform.zsh"
    source "$ZDOTDIR/rc.d/70-zsh-unplugged.zsh"
    source "$ZDOTDIR/rc.d/71-plugins.zsh"
  ' >/dev/null 2>&1
assert_eq "fzf --zsh is invoked exactly once" "1" "$(wc -l < "$fzf_count" | tr -d ' ')"

echo
echo "Zsh startup tests: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]
