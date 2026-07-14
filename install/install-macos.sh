#!/usr/bin/env bash

# Sourced by bootstrap.sh. System actions are selected by its explicit flags.
set -euo pipefail

# Source shared library
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh" 2>/dev/null || source "$(pwd)/install/lib.sh"

: "${DRY_RUN:=}"
: "${INSTALL_PACKAGES:=false}"
: "${APPLY_MACOS_DEFAULTS:=false}"
: "${APPLY_HARDENING:=false}"

HOME=${HOME:-$(get_default_home)}

install_macos_packages() {
  dot_header "Checking for command line tools"
  if ! xcode-select -p &>/dev/null; then
    dot_info "Installing command line tools..."
    execute_cmd "xcode-select --install"
    if [[ -z "$DRY_RUN" ]]; then
      # Wait for installation to complete, but don't hang forever if the
      # user cancels the GUI installer dialog (30 min ceiling).
      local waited=0
      until xcode-select -p &>/dev/null; do
        sleep 5
        waited=$((waited + 5))
        if [[ $waited -ge 1800 ]]; then
          dot_error "Timed out waiting for command line tools installation"
          return 1
        fi
      done
    fi
    dot_success "Installed command line tools"
  else
    dot_info "Command line tools already installed"
  fi

  dot_header "Checking for Rosetta 2"
  if [[ $(uname -m) == "arm64" ]] && [[ ! -f "/Library/Apple/usr/share/rosetta/rosetta" ]]; then
    dot_info "Installing Rosetta 2..."
    if [[ -z "$DRY_RUN" ]]; then
      safe_sudo 600 softwareupdate --install-rosetta --agree-to-license
    else
      echo "[DRY-RUN] sudo softwareupdate --install-rosetta --agree-to-license"
    fi
    dot_success "Installed Rosetta 2"
  else
    dot_info "Rosetta 2 not needed or already installed"
  fi

  # Source and run Homebrew installation.
  # shellcheck source=install/homebrew.sh
  source "$dot_root/install/homebrew.sh"
}

request_sudo() {
  [[ -n "$DRY_RUN" ]] && return 0
  if ! sudo -v; then
    dot_error "Failed to obtain sudo access"
    return 1
  fi
  dot_info "Sudo access granted"
}

apply_macos_defaults() {
  # Capital "Pictures" to match the screencapture location in defaults.zsh.
  dot_mkdir "$HOME"/Pictures/mac-screenshots
  request_sudo || return 1

  dot_info "Applying macOS system defaults..."
  validate_file "$dot_root/config/macos/defaults.zsh" "macOS defaults configuration" || return 1
  execute_cmd "zsh '$dot_root/config/macos/defaults.zsh'" || return 1
  dot_success "Applied macOS defaults"

  dot_header "Cleaning up"
  dot_info "Restarting affected applications..."
  local app
  for app in "Finder" "Dock" "SystemUIServer" "cfprefsd"; do
    # killall fails when the app is not running; that must not abort setup.
    execute_cmd "killall '${app}' &>/dev/null" || true
  done
}

apply_macos_hardening() {
  request_sudo || return 1
  dot_info "Applying macOS security hardening..."
  validate_file "$dot_root/config/macos/harden.zsh" "Security hardening configuration" || return 1
  execute_cmd "zsh '$dot_root/config/macos/harden.zsh'" || return 1
  dot_success "Applied macOS security hardening"
}

run_macos_provisioning() {
  dot_title "Running requested macOS provisioning"

  if [[ "$INSTALL_PACKAGES" == "true" ]]; then
    install_macos_packages
  fi

  if [[ "$APPLY_MACOS_DEFAULTS" == "true" ]]; then
    apply_macos_defaults
  fi

  if [[ "$APPLY_HARDENING" == "true" ]]; then
    apply_macos_hardening
  fi

  if [[ "$APPLY_MACOS_DEFAULTS" == "true" ]] && [[ -z "$DRY_RUN" ]]; then
    dot_info "Some macOS defaults changes require a restart to take effect"
  fi
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  dot_error "Run ./bootstrap.sh with --install-packages, --apply-macos-defaults, or --harden"
  exit 2
fi
