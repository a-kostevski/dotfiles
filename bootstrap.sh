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
readonly DEFAULT_PROFILE=""

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
declare -g PROFILE
declare -g CONFIG_DEST
declare -g BIN_DEST
declare -g DRY_RUN=""
declare -g VERBOSE=false
declare -g SKIP_INSTALL=false
declare -g FORCE=false
declare -g SYNC_MODE=false
declare -ag CUSTOM_CONFIGS=()

# Export key variables early for shared libraries
export dot_root="$SCRIPT_DIR"
export CONFIG_DIR="$SCRIPT_DIR/config"

# Source shared libraries
source "$SCRIPT_DIR/install/lib.sh"
source "$SCRIPT_DIR/install/symlinks.sh"
source "$SCRIPT_DIR/install/profiles.sh"

# Usage information
usage() {
  cat <<EOF
Usage: $SCRIPT_NAME [OPTIONS]

Bootstrap script for installing dotfiles across macOS and Ubuntu.
If no profile is specified, an interactive prompt will help you choose.

OPTIONS:
    -p, --profile <profile>     Installation profile: minimal, standard, full, all
    -c, --config-dest <path>    Config directory path (default: ~/.config)
    -b, --bin-dest <path>       Binary directory path (default: ~/.local/bin)
    -s, --skip-install          Skip OS-specific installation scripts
    -f, --force                 Force overwrite existing files without backup
    -d, --dry-run               Show what would be done without making changes
    -v, --verbose               Enable verbose output
    --sync                      Sync mode: only update symlinks (skip install)
    -h, --help                  Show this help message

PROFILES:
    minimal:  Essential configs only (zsh, git, tmux)
    standard: Common development tools (+ nvim, basic tools)
    full:     Everything including GUI apps and extras
    all:      All existing configs in the config directory

EXAMPLES:
    # Minimal installation with dry run
    $SCRIPT_NAME --profile minimal --dry-run

    # Standard installation with verbose output
    $SCRIPT_NAME --profile standard --verbose

    # Full installation, skip OS packages
    $SCRIPT_NAME --profile full --skip-install

    # Sync configurations only (update symlinks)
    $SCRIPT_NAME --sync

EOF
  exit 0
}

# Interactive profile selection
select_profile() {
  dot_title "Select Installation Profile"
  echo
  echo "Choose which profile to install:"
  echo
  echo "  ${COLOR_INFO}1) minimal${COLOR_RESET}  - Essential configs only"
  echo "     └─ git, zsh, tmux"
  echo
  echo "  ${COLOR_INFO}2) standard${COLOR_RESET} - Common development tools"
  echo "     └─ minimal + nvim, bat, python"
  echo
  echo "  ${COLOR_INFO}3) full${COLOR_RESET}     - Everything including GUI apps"
  echo "     └─ standard + kitty, karabiner, homebrew packages"
  echo
  echo "  ${COLOR_INFO}4) custom${COLOR_RESET}   - Choose individual components"
  echo

  local choice
  while true; do
    printf "Select profile [1-4]: "
    read -r choice

    case "$choice" in
      1)
        PROFILE="minimal"
        dot_success "Selected: minimal profile"
        break
        ;;
      2)
        PROFILE="standard"
        dot_success "Selected: standard profile"
        break
        ;;
      3)
        PROFILE="full"
        dot_success "Selected: full profile"
        break
        ;;
      4)
        select_custom_components
        break
        ;;
      *)
        dot_error "Invalid choice. Please enter 1, 2, 3, or 4."
        ;;
    esac
  done
  echo
}

# Interactive custom component selection
select_custom_components() {
  dot_title "Custom Component Selection"
  echo
  echo "Select which components to install:"
  echo

  # Start with minimal configs
  local -a selected_configs=("git" "zsh" "tmux")

  # Available additional configs
  local -a available_configs=("nvim" "bat" "python" "kitty" "karabiner" "homebrew" "lldb" "clang-format")

  for config in "${available_configs[@]}"; do
    printf "Install %s? [y/N]: " "$config"
    read -r response
    if [[ "$response" =~ ^[Yy]$ ]]; then
      selected_configs+=("$config")
      dot_success "Added: $config"
    fi
  done

  # Set a custom profile flag
  PROFILE="custom"
  CUSTOM_CONFIGS=("${selected_configs[@]}")

  echo
  dot_success "Custom profile created with: ${selected_configs[*]}"
}

# Parse command line arguments
parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -p | --profile)
        PROFILE="${2:-}"
        [[ -z "$PROFILE" ]] && dot_error "Profile requires a value" && exit 1
        shift 2
        ;;
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

  # Validate profile
  case "$PROFILE" in
    minimal | standard | full) ;;
    *)
      dot_error "Invalid profile: $PROFILE"
      dot_error "Valid profiles: minimal, standard, full"
      exit 1
      ;;
  esac

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

# Create symlink with backup
create_symlink() {
  local src="$1"
  local dest="$2"

  # Source must exist
  [[ ! -e "$src" ]] && dot_error "Source not found: $src" && return 1

  # Handle existing symlink
  if [[ -L "$dest" ]]; then
    local current_target=$(readlink "$dest")
    if [[ "$current_target" == "$src" ]]; then
      dot_info "Already linked: $dest"
      return 0
    else
      dot_info "Updating existing symlink: $dest"
      dry_run rm "$dest"
    fi
  # Handle existing file (non-symlink)
  elif [[ -e "$dest" ]]; then
    if [[ "$FORCE" == "true" ]]; then
      dot_warning "Force removing: $dest"
      dry_run rm -rf "$dest"
    else
      local backup="${dest}.backup.$(date +%Y%m%d_%H%M%S)"
      dot_info "Backing up: $dest -> $backup"
      dry_run mv "$dest" "$backup"
    fi
  fi

  # Create symlink
  dot_info "Linking: $src -> $dest"
  dry_run ln -sfn "$src" "$dest"
}

# Get config list based on profile and OS
get_config_list() {
  local -a configs=()

  # Custom profile - use selected components
  if [[ "$PROFILE" == "custom" ]]; then
    if [[ ${#CUSTOM_CONFIGS[@]} -gt 0 ]]; then
      configs=("${CUSTOM_CONFIGS[@]}")
    else
      # Fallback to minimal if no custom configs
      configs+=("git" "zsh" "tmux")
    fi
  else
    # Minimal profile - essentials only
    configs+=("git" "zsh" "tmux")

    # Standard profile - add development tools
    if [[ "$PROFILE" == "standard" || "$PROFILE" == "full" ]]; then
      configs+=("nvim" "bat" "python")
    fi

    # Full profile - add everything
    if [[ "$PROFILE" == "full" ]]; then
      # Cross-platform configs
      configs+=("clang-format" "lldb")

      # macOS-specific configs
      if [[ "$OS_TYPE" == "macos" ]]; then
        configs+=("homebrew" "karabiner" "kitty")
      fi
    fi
  fi

  printf '%s\n' "${configs[@]}"
}

# Clean broken symlinks
clean_broken_symlinks() {
  dot_title "Cleaning Broken Symlinks"

  local count=0

  # Clean in .config directory
  if command -v lnclean &>/dev/null; then
    dot_info "Using lnclean to clean broken symlinks in $CONFIG_DEST"
    if [[ -n "$DRY_RUN" ]]; then
      find "$CONFIG_DEST" -type l ! -exec test -e {} \; -print 2>/dev/null | while read -r link; do
        dot_info "[DRY-RUN] Would remove broken symlink: $link"
        ((count++))
      done
    else
      lnclean "$CONFIG_DEST" 2>/dev/null || true
    fi
  else
    # Fallback to find command
    find "$CONFIG_DEST" -type l ! -exec test -e {} \; -print 2>/dev/null | while read -r link; do
      if [[ -n "$DRY_RUN" ]]; then
        dot_info "[DRY-RUN] Would remove broken symlink: $link"
      else
        rm -f "$link"
        dot_info "Removed broken symlink: $link"
      fi
      ((count++))
    done
  fi

  # Also clean home directory symlinks
  for link in "$HOME/.zshenv" "$HOME/.lldbinit"; do
    if [[ -L "$link" ]] && [[ ! -e "$link" ]]; then
      if [[ -n "$DRY_RUN" ]]; then
        dot_info "[DRY-RUN] Would remove broken symlink: $link"
      else
        rm -f "$link"
        dot_info "Removed broken symlink: $link"
      fi
      ((count++))
    fi
  done

  if [[ $count -gt 0 ]]; then
    dot_success "Cleaned $count broken symlinks"
  else
    dot_info "No broken symlinks found"
  fi
}

# Link configuration files
link_configs() {
  dot_info "[DEBUG] link_configs called with PROFILE=$PROFILE"

  local config_list
  config_list=$(get_config_list "$PROFILE" "$OS_TYPE" 2>/dev/null || echo "")

  dot_info "[DEBUG] config_list content: $(echo "$config_list" | xargs)"
  dot_info "[DEBUG] config_list lines: $(echo "$config_list" | wc -l)"

  dot_title "Linking configuration files"

  if [[ "$VERBOSE" == "true" ]]; then
    dot_info "Profile: $PROFILE, OS: $OS_TYPE"
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

# Link binary scripts based on profile
link_binaries() {
  dot_title "Linking binary scripts"

  create_directory "$BIN_DEST"

  # Determine which scripts to link based on profile
  local pattern="*"
  if [[ "$PROFILE" == "minimal" ]]; then
    # For minimal, skip linking any binaries
    dot_info "Skipping binary scripts for minimal profile"
    return 0
  fi
  # For all other profiles (standard, full, all), link binaries

  # Link scripts
  local count=0
  while IFS= read -r script; do
    # Skip ignored files
    if is_ignored "$script"; then
      dot_info "Skipping ignored script: ${script#$SCRIPT_DIR/}"
      continue
    fi
    create_symlink "$script" "$BIN_DEST/$(basename "$script")"
    ((count++))
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
  )

  # Add development directories for non-minimal profiles
  if [[ "$PROFILE" != "minimal" ]]; then
    dirs+=(
      "$HOME/dev"
      "$HOME/dev/projects"
      "$HOME/dev/scripts"
    )
  fi

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
  echo "  Profile:        $PROFILE"
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

  dot_info "starting"
  # Set defaults and export variables early
  PROFILE="${PROFILE:-$DEFAULT_PROFILE}"
  CONFIG_DEST="${CONFIG_DEST:-$DEFAULT_CONFIG_DEST}"
  BIN_DEST="${BIN_DEST:-$DEFAULT_BIN_DEST}"

  # Debug output
  dot_info "[DEBUG] After defaults: PROFILE='$PROFILE', DEFAULT_PROFILE='$DEFAULT_PROFILE'"

  # Export key variables for install scripts and shared libraries
  export dot_root="$SCRIPT_DIR"
  export CONFIG_DIR="$SCRIPT_DIR/config"
  export DRY_RUN VERBOSE PROFILE SCRIPT_DIR OS_TYPE OS_VERSION FORCE
  export CONFIG_DEST BIN_DEST CUSTOM_CONFIGS

  # Show header
  if [[ "$SYNC_MODE" == "true" ]]; then
    dot_header "Dotfiles Sync v${SCRIPT_VERSION}"
  else
    dot_header "Dotfiles Bootstrap v${SCRIPT_VERSION}"
  fi
  dot_header "OS: ${OS_TYPE} ${OS_VERSION}"
  echo

  # Interactive profile selection if needed
  if [[ -z "$PROFILE" ]] && [[ "$SYNC_MODE" != "true" ]]; then
    select_profile
  fi

  # Sync mode: only update symlinks
  if [[ "$SYNC_MODE" == "true" ]]; then
    dot_info "Running in sync mode - updating symlinks only"
    echo

    # If no profile specified in sync mode, detect current or use minimal
    if [[ -z "$PROFILE" ]]; then
      PROFILE=$(detect_current_profile)
      if [[ -z "$PROFILE" ]]; then
        PROFILE="minimal"
        dot_warning "Could not detect current profile, using minimal"
      else
        dot_info "Using detected profile: $PROFILE"
      fi
    else
      dot_info "Using specified profile: $PROFILE"
    fi

    # Clean broken symlinks first
    if ! clean_broken_symlinks "$CONFIG_DEST" "$DRY_RUN"; then
      dot_warning "Failed to clean some broken symlinks, continuing anyway"
    fi

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
