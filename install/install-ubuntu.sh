#!/usr/bin/env bash

# Sourced by bootstrap.sh when --install-packages is requested.
set -euo pipefail

# Source shared library
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh" 2>/dev/null || source "$(pwd)/install/lib.sh"
# Source declarative package manifest reader (ubuntu_required_apt depends on
# packages_select).
source "$(dirname "${BASH_SOURCE[0]}")/packages.sh" 2>/dev/null || source "$(pwd)/install/packages.sh"

readonly NEOVIM_MIN_VERSION="0.11.0"
readonly NEOVIM_RELEASE_VERSION="0.11.4"

# Compare the numeric major.minor.patch prefix without relying on sort -V or a
# distro-specific package tool.  Neovim release versions do not use suffixes.
neovim_version_at_least() {
  local version="${1#v}"
  local required="${2:-$NEOVIM_MIN_VERSION}"
  local v_major v_minor v_patch r_major r_minor r_patch

  IFS=. read -r v_major v_minor v_patch <<<"$version"
  IFS=. read -r r_major r_minor r_patch <<<"$required"
  v_major="${v_major:-0}"; v_minor="${v_minor:-0}"; v_patch="${v_patch:-0}"
  r_major="${r_major:-0}"; r_minor="${r_minor:-0}"; r_patch="${r_patch:-0}"

  [[ "$v_major" =~ ^[0-9]+$ && "$v_minor" =~ ^[0-9]+$ && "$v_patch" =~ ^[0-9]+$ ]] || return 1
  (( 10#$v_major > 10#$r_major )) && return 0
  (( 10#$v_major < 10#$r_major )) && return 1
  (( 10#$v_minor > 10#$r_minor )) && return 0
  (( 10#$v_minor < 10#$r_minor )) && return 1
  (( 10#$v_patch >= 10#$r_patch ))
}

install_neovim() {
  local installed_version=""
  if command_exists nvim; then
    installed_version="$(nvim --version 2>/dev/null | head -n1 | sed -n 's/^NVIM v//p')"
    if neovim_version_at_least "$installed_version"; then
      dot_info "Neovim $installed_version already satisfies >= $NEOVIM_MIN_VERSION"
      return 0
    fi
  fi

  local arch
  arch="$(dpkg --print-architecture)"
  local asset
  case "$arch" in
    amd64) asset="nvim-linux-x86_64" ;;
    arm64) asset="nvim-linux-arm64" ;;
    *)
      dot_error "No official Neovim $NEOVIM_RELEASE_VERSION archive is configured for Ubuntu architecture: $arch"
      return 1
      ;;
  esac

  local opt_dir="$HOME/.local/opt"
  local install_dir="$opt_dir/$asset-$NEOVIM_RELEASE_VERSION"
  local archive="${TMPDIR:-/tmp}/$asset-$NEOVIM_RELEASE_VERSION.tar.gz"
  local url="https://github.com/neovim/neovim/releases/download/v${NEOVIM_RELEASE_VERSION}/${asset}.tar.gz"

  if [[ -n "$installed_version" ]]; then
    dot_warning "Neovim $installed_version is too old; installing $NEOVIM_RELEASE_VERSION under $HOME/.local"
  else
    dot_info "Installing Neovim $NEOVIM_RELEASE_VERSION under $HOME/.local"
  fi

  execute_cmd "mkdir -p '$opt_dir' '$HOME/.local/bin'"
  if [[ ! -x "$install_dir/bin/nvim" ]]; then
    if [[ -e "$install_dir" ]]; then
      dot_error "Refusing to replace incomplete Neovim installation: $install_dir"
      return 1
    fi
    execute_cmd "curl -fL --retry 3 --retry-delay 2 '$url' -o '$archive'"
    execute_cmd "tar -xzf '$archive' -C '$opt_dir'"
    execute_cmd "mv '$opt_dir/$asset' '$install_dir'"
    execute_cmd "rm -f '$archive'"
  fi
  execute_cmd "ln -sfn '$install_dir/bin/nvim' '$HOME/.local/bin/nvim'"
}

# Pure selector: prints the space-joined apt package set required for <tier>.
# No network, sudo, or filesystem mutation — safe to call from tests.
ubuntu_required_apt() {
  packages_select "$1" apt | tr '\n' ' '
}

# Install eza (modern ls replacement) from its HTTPS apt repository.
install_eza() {
  command_exists eza && return 0
  dot_info "Installing eza..."
  execute_cmd "sudo mkdir -p /etc/apt/keyrings" || return 1
  execute_cmd "wget -qO- https://raw.githubusercontent.com/eza-community/eza/main/deb.asc | sudo gpg --dearmor -o /etc/apt/keyrings/gierens.gpg" || return 1
  execute_cmd "echo \"deb [signed-by=/etc/apt/keyrings/gierens.gpg] https://deb.gierens.de stable main\" | sudo tee /etc/apt/sources.list.d/gierens.list" || return 1
  execute_cmd "sudo chmod 644 /etc/apt/keyrings/gierens.gpg /etc/apt/sources.list.d/gierens.list" || return 1
  execute_cmd "sudo apt-get update" || return 1
  execute_cmd "sudo apt-get install -y eza" || return 1
}

# Install uv. `uv tool install` is the persistent replacement for pipx; uvx
# is intended for one-off, temporary tool execution.
install_uv() {
  command_exists uv && return 0
  dot_info "Installing uv..."
  execute_cmd "curl -LsSf https://astral.sh/uv/install.sh | sh" || return 1
}

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
install_thefuck() {
  command_exists thefuck && return 0
  dot_info "Installing thefuck..."
  local uv_bin
  uv_bin=$(uv_command) || return 1
  execute_cmd "'$uv_bin' tool install thefuck" || return 1
}

# Create symbolic links for tools with different names on Ubuntu.
create_tool_symlinks() {
  if command_exists fdfind && ! command_exists fd; then
    dot_info "Creating fd symlink..."
    execute_cmd "sudo ln -sf $(which fdfind) /usr/local/bin/fd"
  fi

  if command_exists batcat && ! command_exists bat; then
    dot_info "Creating bat symlink..."
    execute_cmd "sudo ln -sf $(which batcat) /usr/local/bin/bat"
  fi
}

install_ubuntu_packages() {
  dot_title "Installing packages for Ubuntu"
  HOME=${HOME:-$(get_default_home)}
  local tier="${PACKAGE_TIER:-minimal}"

  # Required base — atomic; a failure here is a real failure.
  dot_info "Updating package lists..."
  execute_cmd "sudo apt-get update"
  local apt_pkgs; apt_pkgs="$(ubuntu_required_apt "$tier")"
  dot_info "Installing required apt packages ($tier tier)..."
  execute_cmd "sudo apt-get install -y $apt_pkgs"

  # Optional extras — retried, never abort, summarized. Standard/full only.
  case "$tier" in
    standard | full)
      run_optional_step "neovim" retry 3 5 -- install_neovim
      run_optional_step "eza" retry 3 5 -- install_eza
      run_optional_step "uv" retry 3 5 -- install_uv
      run_optional_step "thefuck" retry 3 5 -- install_thefuck
      ;;
  esac

  create_tool_symlinks   # fd/bat compat; local, cheap
  report_optional_failures
  dot_success "Ubuntu package setup completed"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  dot_error "Run ./bootstrap.sh --install-packages"
  exit 2
fi
