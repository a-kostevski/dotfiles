#!/usr/bin/env bash

# Sourced by bootstrap.sh (same options); flags matter when run directly
set -euo pipefail

# Source shared library
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh" 2>/dev/null || source "$(pwd)/install/lib.sh"

: "${DRY_RUN:=}"

dot_title "Installing macOS"

HOME=${HOME:-$(get_default_home)}

# Create macOS-specific directories (bootstrap handles standard directories)
# Capital "Pictures" to match the screencapture location in defaults.zsh
dot_mkdir "$HOME"/Pictures/mac-screenshots

dot_header "Checking for command line tools"
if ! xcode-select -p &>/dev/null; then
  dot_info "Installing command line tools..."
  execute_cmd "xcode-select --install"
  if [[ -z "$DRY_RUN" ]]; then
    # Wait for installation to complete, but don't hang forever if the
    # user cancels the GUI installer dialog (30 min ceiling)
    waited=0
    until xcode-select -p &>/dev/null; do
      sleep 5
      waited=$((waited + 5))
      if [[ $waited -ge 1800 ]]; then
        dot_error "Timed out waiting for command line tools installation"
        exit 1
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

# Source and run Homebrew installation
source "$dot_root/install/homebrew.sh"

# Configure macOS
dot_header "Configuring macOS"

# Request sudo access with timeout (skip in dry run)
if [[ -z "$DRY_RUN" ]]; then
  if ! sudo -v; then
    dot_error "Failed to obtain sudo access"
    exit 1
  fi
  dot_info "Sudo access granted"
fi

# Apply system defaults
dot_info "Applying macOS system defaults..."
if validate_file "$dot_root/config/macos/defaults.zsh" "macOS defaults configuration"; then
  execute_cmd "zsh '$dot_root/config/macos/defaults.zsh'"
  dot_success "Applied macOS defaults"
fi

# Ask for security hardening (skip prompts in dry run / non-interactive
# runs; a plain `read` hitting EOF would abort the script under set -e)
if [[ -z "$DRY_RUN" ]] && [[ -t 0 ]]; then
  read -p "Do you want to apply security hardening? (y/N) " response || response="N"
else
  response="N"
  dot_info "Skipping security hardening prompt (dry run or non-interactive)"
fi
if [[ "$response" =~ ^[Yy]$ ]]; then
  dot_info "Applying security hardening..."
  if validate_file "$dot_root/config/macos/harden.zsh" "Security hardening configuration"; then
    execute_cmd "zsh '$dot_root/config/macos/harden.zsh'"
    dot_success "Applied security hardening"
  fi
fi

# Final cleanup
dot_header "Cleaning up"

# Kill affected applications
dot_info "Restarting affected applications..."
for app in "Finder" "Dock" "SystemUIServer" "cfprefsd"; do
  # killall fails when the app is not running; that must not abort setup
  execute_cmd "killall '${app}' &>/dev/null" || true
done

dot_success "macOS setup completed successfully"
if [[ -z "$DRY_RUN" ]]; then
  dot_info "Note: Some changes require a restart to take effect"
  response="N"
  if [[ -t 0 ]]; then
    read -p "Do you want to restart now? (y/N) " response || response="N"
  fi
  if [[ "$response" =~ ^[Yy]$ ]]; then
    sudo shutdown -r now
  fi
else
  dot_info "Dry run completed - no applications restarted"
fi
