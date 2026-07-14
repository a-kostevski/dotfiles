#!/usr/bin/env bash

# Sourced by bootstrap.sh when --install-packages is requested.
set -euo pipefail

# Source shared library
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh" 2>/dev/null || source "$(pwd)/install/lib.sh"

install_ubuntu_packages() {
  dot_title "Installing packages for Ubuntu"

  HOME=${HOME:-$(get_default_home)}

  dot_header "Installing essential packages"

  # Update package lists
  dot_info "Updating package lists..."
  execute_cmd "sudo apt-get update"

  # Install essential development tools
  dot_info "Installing essential packages..."
  local packages=(
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
    xclip
    python3-pip
    software-properties-common
  )

  execute_cmd "sudo apt-get install -y ${packages[*]}"

  # Install eza (modern ls replacement)
  dot_info "Installing eza..."
  if ! command_exists eza; then
    execute_cmd "sudo mkdir -p /etc/apt/keyrings"
    execute_cmd "wget -qO- https://raw.githubusercontent.com/eza-community/eza/main/deb.asc | sudo gpg --dearmor -o /etc/apt/keyrings/gierens.gpg"
    execute_cmd "echo \"deb [signed-by=/etc/apt/keyrings/gierens.gpg] http://deb.gierens.de stable main\" | sudo tee /etc/apt/sources.list.d/gierens.list"
    execute_cmd "sudo chmod 644 /etc/apt/keyrings/gierens.gpg /etc/apt/sources.list.d/gierens.list"
    execute_cmd "sudo apt-get update"
    execute_cmd "sudo apt-get install -y eza"
  fi

  # Create symbolic links for some tools with different names on Ubuntu
  if command_exists fdfind && ! command_exists fd; then
    dot_info "Creating fd symlink..."
    execute_cmd "sudo ln -sf $(which fdfind) /usr/local/bin/fd"
  fi

  if command_exists batcat && ! command_exists bat; then
    dot_info "Creating bat symlink..."
    execute_cmd "sudo ln -sf $(which batcat) /usr/local/bin/bat"
  fi

  # Install uv first. `uv tool install` is the persistent replacement for
  # pipx; uvx is intended for one-off, temporary tool execution.
  dot_info "Installing uv..."
  if ! command_exists uv; then
    execute_cmd "curl -LsSf https://astral.sh/uv/install.sh | sh"
  fi

  uv_command() {
    if command_exists uv; then
      command -v uv
    elif [[ -x "$HOME/.local/bin/uv" ]]; then
      echo "$HOME/.local/bin/uv"
    elif [[ -n "${DRY_RUN:-}" ]]; then
      # The installer is intentionally not executed in dry-run mode.
      echo "uv"
    else
      dot_error "uv was not found after installation"
      return 1
    fi
  }

  # Install thefuck as a persistent command-line tool. It is lazy-loaded by
  # the Zsh configuration, so uvx's one-off execution model is unsuitable.
  dot_info "Installing thefuck..."
  if ! command_exists thefuck; then
    local uv_bin
    uv_bin=$(uv_command) || return 1
    execute_cmd "'$uv_bin' tool install thefuck"
  fi

  dot_success "Ubuntu package setup completed successfully"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  dot_error "Run ./bootstrap.sh --install-packages"
  exit 2
fi
