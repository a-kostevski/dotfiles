#!/usr/bin/env bash

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"

: "${NVIM_BIN:?NVIM_BIN must be set}"

state_created_by_launcher=0
RUN_NVIM_OUTPUT=""
if [[ -z "${NVIM_SMOKE_STATE:-}" ]]; then
  NVIM_SMOKE_STATE="$(mktemp -d)"
  state_created_by_launcher=1
fi

export HOME="$NVIM_SMOKE_STATE/home"
export XDG_CONFIG_HOME="$NVIM_SMOKE_STATE/config"
export XDG_DATA_HOME="$NVIM_SMOKE_STATE/data"
export XDG_STATE_HOME="$NVIM_SMOKE_STATE/state"
export DOTFILES_REPO_ROOT="$REPO_ROOT"
export DOTFILES_NVIM_SMOKE_LANGUAGES='lua,terraform,cpp,python,javascript,docker,json,yaml'

# Do not inherit a developer cache directory. With XDG_CACHE_HOME unset,
# Neovim's loader cache remains below the isolated HOME directory.
unset XDG_CACHE_HOME

mkdir -p "$HOME" "$XDG_CONFIG_HOME" "$XDG_DATA_HOME" "$XDG_STATE_HOME"
if [[ -L "$XDG_CONFIG_HOME/nvim" ]]; then
  [[ "$(readlink "$XDG_CONFIG_HOME/nvim")" == "$REPO_ROOT/config/nvim" ]] || {
    printf 'nvim config link points outside this repository: %s\n' "$XDG_CONFIG_HOME/nvim" >&2
    exit 1
  }
elif [[ -e "$XDG_CONFIG_HOME/nvim" ]]; then
  printf 'nvim config path already exists: %s\n' "$XDG_CONFIG_HOME/nvim" >&2
  exit 1
else
  ln -s "$REPO_ROOT/config/nvim" "$XDG_CONFIG_HOME/nvim"
fi

if [[ "$state_created_by_launcher" == "1" && "${NVIM_SMOKE_KEEP_STATE:-}" != "1" ]]; then
  trap 'rm -rf "$NVIM_SMOKE_STATE"' EXIT
fi

run_nvim() {
  local output status

  if output="$("$@" 2>&1)"; then
    status=0
  else
    status=$?
  fi
  RUN_NVIM_OUTPUT="$output"

  if [[ -n "$output" ]]; then
    printf '%s\n' "$output" >&2
  fi

  # Neovim's `:qa` exits zero even after a Lua startup error. Treat those
  # emitted errors as failures so the harness is reliable in headless CI.
  if (( status != 0 )) || [[ "$output" == *"Error in "* ]] || [[ "$output" == *"Error detected"* ]]; then
    return 1
  fi
}

case "${1:-smoke}" in
  --sync)
    DOTFILES_NVIM_SMOKE=1 run_nvim "$NVIM_BIN" --headless '+Lazy! sync' +qa
    ;;
  --restore)
    DOTFILES_NVIM_SMOKE=1 run_nvim "$NVIM_BIN" --headless '+Lazy! restore' +qa
    ;;
  smoke)
    if DOTFILES_NVIM_SMOKE=1 DOTFILES_NVIM_OFFLINE=1 \
      run_nvim "$NVIM_BIN" --headless \
      "+lua dofile(vim.env.DOTFILES_REPO_ROOT .. '/tests/nvim/smoke.lua')" +qa; then
      smoke_status=0
    else
      smoke_status=$?
    fi

    if [[ "$RUN_NVIM_OUTPUT" == *"Downloading tree-sitter" ]] || [[ "$RUN_NVIM_OUTPUT" == *"[nvim-treesitter/install/"* ]]; then
      printf 'nvim smoke test: Tree-sitter attempted a parser download\n' >&2
      exit 1
    fi

    mason_packages="$XDG_DATA_HOME/nvim/mason/packages"
    if [[ -d "$mason_packages" ]] && [[ -n "$(find "$mason_packages" -mindepth 1 -maxdepth 1 -print -quit)" ]]; then
      printf 'nvim smoke test: Mason installed package(s) under %s\n' "$mason_packages" >&2
      exit 1
    fi

    exit "$smoke_status"
    ;;
  *)
    printf 'usage: %s [--sync|--restore]\n' "$0" >&2
    exit 64
    ;;
esac
