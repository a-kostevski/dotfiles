#!/usr/bin/env bash
# Unit tests for the declarative manifest reader (install/manifest.sh).
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$REPO_ROOT" || exit 1

# shellcheck source=tests/lib.sh
source "$REPO_ROOT/tests/lib.sh"
export dot_root="$REPO_ROOT"
# shellcheck source=/dev/null
source "$REPO_ROOT/install/lib.sh"
# shellcheck source=/dev/null
source "$REPO_ROOT/install/manifest.sh"

echo "== manifest_records parsing =="
records="$(manifest_records)"
assert_contains "git entry parsed" "git|tree|config/git|{XDG_CONFIG}/git|minimal,standard,full|all" "$records"
assert_contains "zsh-env file entry parsed" "zsh-env|file|config/zsh/zshenv|{HOME}/.zshenv|minimal,standard,full|all" "$records"
assert_contains "lldb-init is macos only" "lldb-init|file|config/lldb/.lldbinit|{HOME}/.lldbinit|full|macos" "$records"

echo "== manifest_select profile filtering =="
min="$(manifest_select minimal macos)"
assert_contains "minimal includes git" $'\ngit|' $'\n'"$min"
assert_eq "minimal excludes nvim" "" "$(grep '^nvim|' <<<"$min" || true)"

std="$(manifest_select standard macos)"
assert_contains "standard includes nvim" "nvim|tree" "$std"
assert_eq "standard excludes clang-format" "" "$(grep '^clang-format|' <<<"$std" || true)"

echo "== manifest_select platform gating =="
full_ubuntu="$(manifest_select full ubuntu)"
assert_eq "full/ubuntu excludes kitty" "" "$(grep '^kitty|' <<<"$full_ubuntu" || true)"
assert_eq "full/ubuntu excludes lldb-init home file" "" "$(grep '^lldb-init|' <<<"$full_ubuntu" || true)"
assert_contains "full/ubuntu keeps lldb tree" "lldb|tree" "$full_ubuntu"
full_macos="$(manifest_select full macos)"
assert_contains "full/macos includes kitty" "kitty|tree" "$full_macos"
assert_contains "full/macos includes lldb-init" "lldb-init|file" "$full_macos"
assert_eq "homebrew not a link component" "" "$(grep '^homebrew|' <<<"$full_macos" || true)"

echo "== all profile =="
all_macos="$(manifest_select all macos)"
assert_contains "all includes op" "op|tree" "$all_macos"
assert_contains "all includes nvim" "nvim|tree" "$all_macos"

echo "== manifest_links tree expansion + shadowing =="
links_min="$(manifest_links minimal macos)"
assert_contains "zsh tree links .zshrc under XDG" \
  "$REPO_ROOT/config/zsh/.zshrc|$HOME/.config/zsh/.zshrc" "$links_min"
assert_contains "zshenv is linked to HOME" \
  "$REPO_ROOT/config/zsh/zshenv|$HOME/.zshenv" "$links_min"
assert_eq "zshenv is shadowed out of the zsh tree" "" \
  "$(grep -F "config/zsh/zshenv|$HOME/.config/zsh/zshenv" <<<"$links_min" || true)"
assert_contains "bin tree links a script into BIN" \
  "$REPO_ROOT/bin/mkx|$HOME/.local/bin/mkx" "$links_min"

echo "== manifest_links home files (full) =="
links_full="$(manifest_links full macos)"
assert_contains "clang-format links to home" \
  "$REPO_ROOT/config/clang-format|$HOME/.clang-format" "$links_full"
assert_contains "curl links to home" \
  "$REPO_ROOT/config/.curlrc|$HOME/.curlrc" "$links_full"
assert_contains "lldbinit.py links under XDG" \
  "$REPO_ROOT/config/lldb/lldbinit.py|$HOME/.config/lldb/lldbinit.py" "$links_full"
assert_contains ".lldbinit links to home on macos" \
  "$REPO_ROOT/config/lldb/.lldbinit|$HOME/.lldbinit" "$links_full"
assert_eq ".lldbinit shadowed out of lldb tree on macos" "" \
  "$(grep -F "config/lldb/.lldbinit|$HOME/.config/lldb/.lldbinit" <<<"$links_full" || true)"

echo "== lldb on ubuntu keeps XDG .lldbinit (not shadowed) =="
links_full_ubuntu="$(manifest_links full ubuntu)"
assert_contains "ubuntu links .lldbinit under XDG (no home file selected)" \
  "$REPO_ROOT/config/lldb/.lldbinit|$HOME/.config/lldb/.lldbinit" "$links_full_ubuntu"

echo "== components + component_links + exists + home_dests =="
comps="$(manifest_components full macos)"
assert_contains "components include zsh" $'\nzsh\n' $'\n'"$comps"$'\n'
assert_eq "zsh-env is not its own component" "" "$(grep -x 'zsh-env' <<<"$comps" || true)"
zsh_links="$(manifest_component_links zsh macos)"
assert_contains "component zsh includes tree file" \
  "$REPO_ROOT/config/zsh/.zshrc|$HOME/.config/zsh/.zshrc" "$zsh_links"
assert_contains "component zsh includes home zshenv" \
  "$REPO_ROOT/config/zsh/zshenv|$HOME/.zshenv" "$zsh_links"
assert_eq "manifest_component_exists nvim" "0" "$(manifest_component_exists nvim; echo $?)"
assert_eq "manifest_component_exists bogus" "1" "$(manifest_component_exists bogus; echo $?)"
home_macos="$(manifest_home_dests macos)"
assert_contains "home_dests has zshenv" "$HOME/.zshenv" "$home_macos"
assert_contains "home_dests has clang-format" "$HOME/.clang-format" "$home_macos"
assert_contains "home_dests has curl" "$HOME/.curlrc" "$home_macos"
assert_contains "home_dests has lldbinit on macos" "$HOME/.lldbinit" "$home_macos"
assert_eq "home_dests omits lldbinit on ubuntu" "" \
  "$(grep -F "$HOME/.lldbinit" <<<"$(manifest_home_dests ubuntu)" || true)"

echo "== manifest_component_links OS-gates file entries =="
lldb_macos="$(manifest_component_links lldb macos)"
assert_contains "lldb/macos emits ~/.lldbinit" \
  "$REPO_ROOT/config/lldb/.lldbinit|$HOME/.lldbinit" "$lldb_macos"
assert_eq "lldb/macos shadows .lldbinit out of XDG" "" \
  "$(grep -F "config/lldb/.lldbinit|$HOME/.config/lldb/.lldbinit" <<<"$lldb_macos" || true)"
lldb_ubuntu="$(manifest_component_links lldb ubuntu)"
assert_eq "lldb/ubuntu omits ~/.lldbinit home file" "" \
  "$(grep -F "$HOME/.lldbinit" <<<"$lldb_ubuntu" || true)"
assert_contains "lldb/ubuntu keeps .lldbinit under XDG" \
  "$REPO_ROOT/config/lldb/.lldbinit|$HOME/.config/lldb/.lldbinit" "$lldb_ubuntu"

echo "== hook change-detection covers the manifest =="
hook_pattern='^(config/|install/|bin/|bootstrap\.sh$)'
assert_eq "manifest.toml matches the hook trigger" "install/manifest.toml" \
  "$(printf 'install/manifest.toml\n' | grep -E "$hook_pattern")"
assert_eq "post-checkout uses the lifecycle pattern" "yes" \
  "$([[ "$(cat "$REPO_ROOT/.githooks/post-checkout")" == *'install/'* ]] && echo yes || echo no)"

echo
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
