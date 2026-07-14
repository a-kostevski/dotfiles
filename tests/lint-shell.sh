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
