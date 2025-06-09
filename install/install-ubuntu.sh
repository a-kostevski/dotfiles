#!/usr/bin/env bash

# Source shared library
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh" 2>/dev/null || source "$(pwd)/install/lib.sh"

dot_title "Installing for Ubuntu"

HOME=${HOME:-$(get_default_home)}

# Bootstrap handles standard directory creation

dot_header "Installing essential packages"

# Update package lists
dot_info "Updating package lists..."
execute_cmd "sudo apt-get update"

# Install essential development tools
dot_info "Installing essential packages..."
PACKAGES=(
  build-essential
  curl
  git
  wget
  zsh
  tmux
  neovim
  ripgrep
  fd-find
  bat
  fzf
  htop
  tree
  jq
  unzip
)

execute_cmd "sudo apt-get install -y ${PACKAGES[*]}"

# Create symbolic links for some tools with different names on Ubuntu
if command_exists fdfind && ! command_exists fd; then
  dot_info "Creating fd symlink..."
  execute_cmd "sudo ln -sf $(which fdfind) /usr/local/bin/fd"
fi

if command_exists batcat && ! command_exists bat; then
  dot_info "Creating bat symlink..."
  execute_cmd "sudo ln -sf $(which batcat) /usr/local/bin/bat"
fi

dot_success "Ubuntu setup completed successfully"