#!/usr/bin/env bash

# Unified Bootstrap Script for Dotfiles
# Supports: macOS, Ubuntu/Debian
# Version: 3.0.0

set -e

# Trap errors for better debugging
trap 'echo "Error occurred at line $LINENO while executing: $BASH_COMMAND"' ERR

# Script metadata
readonly SCRIPT_VERSION="3.0.0"
readonly SCRIPT_DATE="2025-06-09"
readonly SCRIPT_NAME=$(basename "$0")
readonly SCRIPT_DIR="$(cd "$(dirname "${0}")" && pwd -P)"

# Configuration constants
readonly DEFAULT_CONFIG_DEST="${HOME}/.config"
readonly DEFAULT_BIN_DEST="${HOME}/.local/bin"

# Color constants
readonly COLOR_HEADER="\033[1;36m"
readonly COLOR_INFO="\033[34m"
readonly COLOR_ERROR="\033[31m"
readonly COLOR_SUCCESS="\033[32m"
readonly COLOR_WARNING="\033[33m"
readonly COLOR_RESET="\033[0m"

# Global variables
declare -g OS_TYPE
declare -g OS_VERSION
declare -g CONFIG_DEST
declare -g BIN_DEST
declare -g DRY_RUN=""
declare -g VERBOSE=false
declare -g SKIP_INSTALL=false
declare -g FORCE=false
declare -g SYNC_MODE=false

# Export key variables early for shared libraries
export dot_root="$SCRIPT_DIR"
export CONFIG_DIR="$SCRIPT_DIR/config"

# Source shared libraries
source "$SCRIPT_DIR/install/lib.sh"
source "$SCRIPT_DIR/install/symlinks.sh"

# Usage information
usage() {
  cat <<EOF
Usage: $SCRIPT_NAME [OPTIONS]

Bootstrap script for installing dotfiles across macOS and Ubuntu.
Syncs all configurations in the config/ directory by default.

OPTIONS:
    -c, --config-dest <path>    Config directory path (default: ~/.config)
    -b, --bin-dest <path>       Binary directory path (default: ~/.local/bin)
    -s, --skip-install          Skip OS-specific installation scripts
    -f, --force                 Force overwrite existing files without backup
    -d, --dry-run               Show what would be done without making changes
    -v, --verbose               Enable verbose output
    --sync                      Sync mode: only update symlinks (skip install)
    -h, --help                  Show this help message

EXAMPLES:
    # Installation with dry run
    $SCRIPT_NAME --dry-run

    # Installation with verbose output
    $SCRIPT_NAME --verbose

    # Installation, skip OS packages
    $SCRIPT_NAME --skip-install

    # Sync configurations only (update symlinks)
    $SCRIPT_NAME --sync

EOF
  exit 0
}


# Parse command line arguments
parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -c | --config-dest)
        CONFIG_DEST="${2:-}"
        [[ -z "$CONFIG_DEST" ]] && dot_error "Config destination requires a value" && exit 1
        shift 2
        ;;
      -b | --bin-dest)
        BIN_DEST="${2:-}"
        [[ -z "$BIN_DEST" ]] && dot_error "Bin destination requires a value" && exit 1
        shift 2
        ;;
      -s | --skip-install)
        SKIP_INSTALL=true
        shift
        ;;
      -f | --force)
        FORCE=true
        shift
        ;;
      -d | --dry-run)
        DRY_RUN="dry_run"
        shift
        ;;
      -v | --verbose)
        VERBOSE=true
        shift
        ;;
      --sync)
        SYNC_MODE=true
        SKIP_INSTALL=true
        shift
        ;;
      -h | --help)
        usage
        ;;
      *)
        dot_error "Unknown option: $1"
        usage
        ;;
    esac
  done
}

# Validate environment
validate_environment() {
  # Check OS support
  if [[ "$OS_TYPE" == "unsupported" ]]; then
    dot_error "Unsupported operating system"
    dot_error "This script supports macOS and Ubuntu/Debian only"
    exit 1
  fi

  # Check required commands
  local required_commands=("git" "curl")
  [[ "$OS_TYPE" == "ubuntu" ]] && required_commands+=("sudo")

  for cmd in "${required_commands[@]}"; do
    if ! command -v "$cmd" &>/dev/null; then
      dot_error "Required command not found: $cmd"
      exit 1
    fi
  done

  # Check source directories
  if [[ ! -d "$SCRIPT_DIR/config" ]]; then
    dot_error "Config directory not found at: $SCRIPT_DIR/config"
    exit 1
  fi
  if [[ ! -d "$SCRIPT_DIR/bin" ]]; then
    dot_error "Bin directory not found at: $SCRIPT_DIR/bin"
    exit 1
  fi
}

# Create directory with proper permissions
create_directory() {
  local dir="$1"
  if [[ ! -d "$dir" ]]; then
    dot_info "Creating directory: $dir"
    dry_run mkdir -p "$dir"
  fi
}

# Check if a file should be ignored based on .gitignore patterns
is_ignored() {
  local file="$1"
  local rel_path="${file#$SCRIPT_DIR/}"

  # Use git check-ignore if we're in a git repo
  if [[ -d "$SCRIPT_DIR/.git" ]] && command -v git &>/dev/null; then
    git -C "$SCRIPT_DIR" check-ignore -q "$rel_path" 2>/dev/null
    return $?
  fi

  # Fallback: manually check common patterns
  local basename
  basename=$(basename "$file")

  # Check common ignore patterns
  case "$basename" in
    .DS_Store | *.local | *.claude | Brewfile*.lock.json)
      return 0
      ;;
  esac

  return 1
}

# Note: create_symlink is defined in install/symlinks.sh

# Get all config directories
get_config_list() {
  local -a configs=()
  
  # Find all directories in the config directory
  if [[ -d "$SCRIPT_DIR/config" ]]; then
    while IFS= read -r dir; do
      local config_name
      config_name=$(basename "$dir")
      # Skip hidden directories
      if [[ ! "$config_name" =~ ^\. ]]; then
        configs+=("$config_name")
      fi
    done < <(find "$SCRIPT_DIR/config" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sort)
  fi
  
  printf '%s\n' "${configs[@]}"
}


# Link configuration files
link_configs() {
  local config_list
  config_list=$(get_config_list)

  dot_title "Linking configuration files"

  if [[ "$VERBOSE" == "true" ]]; then
    dot_info "OS: $OS_TYPE"
    dot_info "Configs to link: $(echo "$config_list" | xargs | sed 's/ /, /g')"
  fi

  # Link each config directory
  while IFS= read -r config; do
    local src="$SCRIPT_DIR/config/$config"

    if [[ -d "$src" ]]; then
      dot_info "Processing $config configuration..."

      # Get all symlinks for this config and create them
      get_config_symlinks "$config" "$src" "$CONFIG_DEST" | while IFS='|' read -r source dest; do
        create_symlink "$source" "$dest"
      done
    fi
  done <<<"$config_list"

  dot_success "Configuration files linked"
}

# Link binary scripts
link_binaries() {
  dot_title "Linking binary scripts"

  create_directory "$BIN_DEST"

  # Link all scripts
  local count=0
  while IFS= read -r script; do
    # Skip ignored files
    if is_ignored "$script"; then
      dot_info "Skipping ignored script: ${script#$SCRIPT_DIR/}"
      continue
    fi
    create_symlink "$script" "$BIN_DEST/$(basename "$script")"
    ((count++)) || true
  done < <(find "$SCRIPT_DIR/bin" -type f -not -name ".*" 2>/dev/null)

  # Set permissions
  [[ -d "$BIN_DEST" ]] && dry_run chmod -R 755 "$BIN_DEST"

  dot_success "Linked $count binary scripts"
}

# Run OS-specific installation
run_os_installation() {
  [[ "$SKIP_INSTALL" == "true" ]] && return 0

  dot_title "Running OS-specific installation"

  case "$OS_TYPE" in
    macos)
      source "$SCRIPT_DIR/install/install-macos.sh"
      ;;
    ubuntu)
      source "$SCRIPT_DIR/install/install-ubuntu.sh"
      ;;
  esac
}

# Create standard directory structure
create_directories() {
  dot_title "Creating directory structure"

  local dirs=(
    "$HOME/.cache"
    "$HOME/.config"
    "$HOME/.local"
    "$HOME/.local/bin"
    "$HOME/.local/share"
    "$HOME/.local/state"
    "$HOME/dev"
    "$HOME/dev/projects"
    "$HOME/dev/scripts"
  )

  for dir in "${dirs[@]}"; do
    create_directory "$dir"
  done

  dot_success "Directory structure created"
}

# Show summary
show_summary() {
  dot_title "Installation Summary"

  echo "  OS Type:        $OS_TYPE"
  echo "  OS Version:     $OS_VERSION"
  echo "  Config Path:    $CONFIG_DEST"
  echo "  Binary Path:    $BIN_DEST"
  echo "  Dry Run:        $([[ -n "$DRY_RUN" ]] && echo "Yes" || echo "No")"
  echo

  if [[ -z "$DRY_RUN" ]]; then
    dot_success "Bootstrap completed successfully!"

    # Post-installation instructions
    case "$OS_TYPE" in
      ubuntu)
        if command -v zsh &>/dev/null && [[ "$SHELL" != *"zsh"* ]]; then
          echo
          dot_info "To set zsh as your default shell, run:"
          echo "    chsh -s \$(which zsh)"
        fi
        ;;
      macos)
        echo
        dot_info "Some changes may require a restart to take effect"
        ;;
    esac

    echo
    dot_info "Restart your terminal or run: source ~/.zshenv"
  else
    echo
    dot_info "This was a dry run. No changes were made."
    dot_info "Remove --dry-run to apply changes."
  fi
}

# Main execution
main() {
  # Detect OS
  detect_os

  # Set defaults and export variables early
  CONFIG_DEST="${CONFIG_DEST:-$DEFAULT_CONFIG_DEST}"
  BIN_DEST="${BIN_DEST:-$DEFAULT_BIN_DEST}"

  # Export key variables for install scripts and shared libraries
  export dot_root="$SCRIPT_DIR"
  export CONFIG_DIR="$SCRIPT_DIR/config"
  export DRY_RUN VERBOSE SCRIPT_DIR OS_TYPE OS_VERSION FORCE
  export CONFIG_DEST BIN_DEST

  # Show header
  if [[ "$SYNC_MODE" == "true" ]]; then
    dot_header "Dotfiles Sync v${SCRIPT_VERSION}"
  else
    dot_header "Dotfiles Bootstrap v${SCRIPT_VERSION}"
  fi
  dot_header "OS: ${OS_TYPE} ${OS_VERSION}"
  echo

  # Sync mode: only update symlinks
  if [[ "$SYNC_MODE" == "true" ]]; then
    dot_info "Running in sync mode - updating symlinks only"
    echo

    # Clean broken symlinks first
    clean_broken_symlinks

    # Create minimal directory structure
    create_directory "$CONFIG_DEST"
    create_directory "$BIN_DEST"

    # Link configurations
    link_configs

    # Link binaries
    link_binaries

    dot_success "Sync completed successfully!"
    echo
    dot_info "Restart your terminal or run: source ~/.zshenv"
  else
    # Normal bootstrap mode
    # Validate environment
    validate_environment

    # Create directories
    create_directories

    # Run OS installation
    run_os_installation

    # Link configurations
    link_configs

    # Link binaries
    link_binaries

    # Show summary
    show_summary
  fi
}

# Run the script
parse_args "$@"
main
