#!/usr/bin/env bash

dot_title "Installing for Ubuntu"

HOME=${HOME:-"/home/$(whoami)"}

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

dot_header "Installing essential packages"

# Update package lists
dot_info "Updating package lists..."
$dry_run sudo apt-get update

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

$dry_run sudo apt-get install -y "${PACKAGES[@]}"

# Create symbolic links for some tools with different names on Ubuntu
if command -v fdfind >/dev/null 2>&1 && ! command -v fd >/dev/null 2>&1; then
  dot_info "Creating fd symlink..."
  $dry_run sudo ln -sf $(which fdfind) /usr/local/bin/fd
fi

if command -v batcat >/dev/null 2>&1 && ! command -v bat >/dev/null 2>&1; then
  dot_info "Creating bat symlink..."
  $dry_run sudo ln -sf $(which batcat) /usr/local/bin/bat
fi

dot_success "Ubuntu setup completed successfully"