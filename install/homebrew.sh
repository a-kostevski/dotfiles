#!/usr/bin/env bash

# Sourced by install-macos.sh under bootstrap (same options); flags matter
# when this script is executed directly
set -euo pipefail

# Source shared library
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh" 2>/dev/null || source "$(pwd)/install/lib.sh"

if ! declare -f packages_select >/dev/null; then
  source "$dot_root/install/packages.sh"
fi

: "${DRY_RUN:=}"

# Get the appropriate Homebrew prefix
BREW_PREFIX=$(get_brew_prefix)

# Install Homebrew if not present
install_homebrew() {
  if ! command_exists brew; then
    dot_info "Installing Homebrew..."
    if execute_cmd 'NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'; then
      # Add Homebrew to PATH for the current session
      if [[ -z "$DRY_RUN" ]]; then
        if [[ -x "$BREW_PREFIX/bin/brew" ]]; then
          eval "$("$BREW_PREFIX/bin/brew" shellenv)"
        else
          dot_error "brew not found at $BREW_PREFIX/bin/brew after install"
          return 1
        fi
      fi
    else
      dot_error "Failed to install Homebrew"
      return 1
    fi
  else
    dot_info "Homebrew is already installed"
  fi
}

# Link the Homebrew environment file (analytics/redirect settings, etc.)
# before any brew invocation so the settings are in effect for the bundle.
link_brew_env() {
  local src="$dot_root/config/homebrew/brew.env"
  local dest="$HOME/.config/homebrew/brew.env"
  validate_file "$src" "Homebrew environment file" || return 1
  create_symlink "$src" "$dest"
}

# Pure: emit a Brewfile for a tier. Testable without brew.
generate_brewfile() {
  local tier="$1" out="$2" name
  : >"$out"
  while IFS= read -r name; do [[ -n "$name" ]] && printf 'brew "%s"\n' "$name" >>"$out"; done < <(packages_select "$tier" brew)
  while IFS= read -r name; do [[ -n "$name" ]] && printf 'cask "%s"\n' "$name" >>"$out"; done < <(packages_select "$tier" cask)
}

# Install packages for the current PACKAGE_TIER via a generated Brewfile.
install_packages() {
  local tier="${PACKAGE_TIER:-minimal}"
  local brewfile; brewfile="$(mktemp)"
  generate_brewfile "$tier" "$brewfile"
  dot_info "Installing Homebrew packages ($tier tier)..."
  if execute_cmd "brew bundle --file='$brewfile'"; then
    dot_success "Installed Homebrew packages"
    rm -f "$brewfile"
  else
    dot_error "Failed to install some Homebrew packages"
    rm -f "$brewfile"
    return 1
  fi
}

# Main execution
main() {
  install_homebrew || return 1
  link_brew_env || return 1 # before any brew bundle
  install_packages || return 1
  return 0
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi

