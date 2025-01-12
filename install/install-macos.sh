#!/usr/bin/env bash

dot_title "Installing macOS"

HOME=${HOME:-"/Users/$(whoami)"}

# Create necessary directories
dot_mkdir "$HOME"/dev
dot_mkdir "$HOME"/dev/projects
dot_mkdir "$HOME"/dev/scripts
dot_mkdir "$HOME"/.cache
dot_mkdir "$HOME"/.config
dot_mkdir "$HOME"/.local
dot_mkdir "$HOME"/.local/bin
dot_mkdir "$HOME"/.local/share
dot_mkdir "$HOME"/.local/state
dot_mkdir "$HOME"/pictures/mac-screenshots

dot_header "Checking for command line tools"
if ! xcode-select -p &>/dev/null; then
  dot_info "Installing command line tools..."
  xcode-select --install
  # Wait for installation to complete
  until xcode-select -p &>/dev/null; do
    sleep 1
  done
  dot_success "Installed command line tools"
else
  dot_info "Command line tools already installed"
fi

dot_header "Checking for Rosetta 2"
if [[ $(uname -m) == "arm64" ]] && [[ ! -f "/Library/Apple/usr/share/rosetta/rosetta" ]]; then
  dot_info "Installing Rosetta 2..."
  sudo softwareupdate --install-rosetta --agree-to-license
  dot_success "Installed Rosetta 2"
else
  dot_info "Rosetta 2 not needed or already installed"
fi

# Source and run Homebrew installation
source "$dot_root/install/homebrew.sh"

# Configure macOS
dot_header "Configuring macOS"

# Ask for sudo password upfront
sudo -v
# Keep sudo alive
while true; do
  sudo -n true
  sleep 60
  kill -0 "$$" || exit
done 2>/dev/null &

# Apply system defaults
dot_info "Applying macOS system defaults..."
if [ -f "$dot_root/config/macos/defaults.zsh" ]; then
  zsh "$dot_root/config/macos/defaults.zsh"
  dot_success "Applied macOS defaults"
else
  dot_error "macOS defaults configuration not found"
fi

# Ask for security hardening
read -p "Do you want to apply security hardening? (y/N) " response
if [[ "$response" =~ ^[Yy]$ ]]; then
  dot_info "Applying security hardening..."
  if [ -f "$dot_root/config/macos/harden.zsh" ]; then
    zsh "$dot_root/config/macos/harden.zsh"
    dot_success "Applied security hardening"
  else
    dot_error "Security hardening configuration not found"
  fi
fi

# Final cleanup
dot_header "Cleaning up"

# Kill affected applications
dot_info "Restarting affected applications..."
for app in "Finder" "Dock" "SystemUIServer" "cfprefsd"; do
  killall "${app}" &>/dev/null
done

dot_success "macOS setup completed successfully"
dot_info "Note: Some changes require a restart to take effect"
read -p "Do you want to restart now? (y/N) " response
if [[ "$response" =~ ^[Yy]$ ]]; then
  sudo shutdown -r now
fi
