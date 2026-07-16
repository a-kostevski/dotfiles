#!/usr/bin/env bash

# Unified Bootstrap Script for Dotfiles
# Supports: macOS, Ubuntu/Debian
# Version: 3.0.0

# install/manifest.sh needs associative arrays; stock macOS bash is 3.2
if ((BASH_VERSINFO[0] < 4)); then
  echo "Error: bootstrap.sh requires bash 4 or newer (found $BASH_VERSION)." >&2
  echo "On macOS: brew install bash, then re-run." >&2
  exit 1
fi

set -euo pipefail

# Trap errors for better debugging
trap 'echo "Error occurred at line $LINENO while executing: $BASH_COMMAND" >&2' ERR

# Script metadata
readonly SCRIPT_VERSION="3.0.0"
# shellcheck disable=SC2034  # grepped by `make version`
readonly SCRIPT_DATE="2025-06-09"
SCRIPT_NAME=$(basename "$0")
readonly SCRIPT_NAME
SCRIPT_DIR="$(cd "$(dirname "${0}")" && pwd -P)"
readonly SCRIPT_DIR

# Configuration constants
readonly DEFAULT_CONFIG_DEST="${HOME}/.config"
readonly DEFAULT_BIN_DEST="${HOME}/.local/bin"

# Global variables
declare -g OS_TYPE=""
declare -g OS_VERSION=""
declare -g CONFIG_DEST
declare -g BIN_DEST
declare -g PROFILE="minimal"
declare -g PROFILE_EXPLICIT=false
declare -g DRY_RUN=""
declare -g VERBOSE=false
declare -g SKIP_INSTALL=false
declare -g INSTALL_PACKAGES=false
declare -g PACKAGE_TIER=""
declare -g PACKAGE_TIER_OVERRIDE=""
declare -g APPLY_MACOS_DEFAULTS=false
declare -g APPLY_HARDENING=false
declare -g FORCE=false
declare -g SYNC_MODE=false
declare -g SYNC_CONFIG=""

# Export key variables early for shared libraries
export dot_root="$SCRIPT_DIR"
export CONFIG_DIR="$SCRIPT_DIR/config"

# Source shared libraries
source "$SCRIPT_DIR/install/lib.sh"
source "$SCRIPT_DIR/install/symlinks.sh"
source "$SCRIPT_DIR/install/manifest.sh"
source "$SCRIPT_DIR/install/packages.sh"

# Usage information
usage() {
  cat <<EOF
Usage: $SCRIPT_NAME [OPTIONS]

Bootstrap script for linking dotfiles across macOS and Ubuntu.
Syncs all configurations in the config/ directory by default. Package
installation and macOS system changes require explicit opt-in flags.

OPTIONS:
    -p, --profile <name>        Installation profile: minimal, standard, full, all
                                (default: the stored profile from a previous
                                run, else minimal)
    --config <name>             Sync only a specific config (e.g., nvim, zsh)
    --install-packages          Install OS-specific packages (explicit opt-in)
    --packages <tier>           Package tier: minimal, standard, full
                                (requires --install-packages; default: the
                                profile's tier, e.g. standard -> standard)
    --apply-macos-defaults      Apply macOS system defaults (macOS only)
    --harden                    Apply macOS security hardening (macOS only)
    -s, --skip-install          Legacy compatibility flag; packages are already
                                skipped unless --install-packages is provided
    -f, --force                 Force overwrite existing files without backup
    -n, --dry-run               Show what would be done without making changes
    -v, --verbose               Enable verbose output
    --sync                      Sync mode: only update symlinks (skip install)
    -h, --help                  Show this help message

PROFILES:
    minimal                     Essential configs: git, zsh, tmux
    standard                    Development tools: minimal + nvim, bat, python
    full                        Complete setup: standard + clang-format, lldb,
                                GUI apps (macOS: karabiner, kitty, homebrew)
    all                         All available configs in config/ directory

EXAMPLES:
    # Install with minimal profile (default)
    $SCRIPT_NAME

    # Install with standard profile
    $SCRIPT_NAME --profile standard

    # Install with full profile
    $SCRIPT_NAME --profile full

    # Installation with dry run
    $SCRIPT_NAME --dry-run

    # Installation with verbose output
    $SCRIPT_NAME --verbose

    # Link configs and install OS packages
    $SCRIPT_NAME --install-packages

    # Install OS packages at a tier different from the link profile
    $SCRIPT_NAME --install-packages --packages full

    # Apply macOS defaults only (macOS)
    $SCRIPT_NAME --apply-macos-defaults

    # Apply macOS security hardening only (macOS)
    $SCRIPT_NAME --harden

    # Sync configurations only (update symlinks)
    $SCRIPT_NAME --sync

    # Sync with different profile
    $SCRIPT_NAME --sync --profile standard

    # Sync a specific config only
    $SCRIPT_NAME --sync --config nvim

EOF
}


# Parse command line arguments
parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -p | --profile)
        PROFILE="${2:-}"
        [[ -z "$PROFILE" ]] && dot_error "Profile requires a value" && exit 1
        validate_profile "$PROFILE" || exit 1
        PROFILE_EXPLICIT=true
        shift 2
        ;;
      -s | --skip-install)
        SKIP_INSTALL=true
        shift
        ;;
      --install-packages)
        INSTALL_PACKAGES=true
        shift
        ;;
      --packages)
        PACKAGE_TIER_OVERRIDE="${2:-}"
        [[ -z "$PACKAGE_TIER_OVERRIDE" ]] && dot_error "--packages requires a tier" && exit 1
        validate_tier "$PACKAGE_TIER_OVERRIDE" || exit 1
        shift 2
        ;;
      --apply-macos-defaults)
        APPLY_MACOS_DEFAULTS=true
        shift
        ;;
      --harden)
        APPLY_HARDENING=true
        shift
        ;;
      -f | --force)
        FORCE=true
        shift
        ;;
      -n | --dry-run)
        DRY_RUN="dry_run"
        shift
        ;;
      -v | --verbose)
        VERBOSE=true
        shift
        ;;
      --sync)
        SYNC_MODE=true
        shift
        ;;
      --config)
        SYNC_CONFIG="${2:-}"
        [[ -z "$SYNC_CONFIG" ]] && dot_error "Config requires a name" && exit 1
        shift 2
        ;;
      -h | --help)
        usage
        exit 0
        ;;
      *)
        dot_error "Unknown option: $1"
        usage >&2
        exit 2
        ;;
    esac
  done

  if [[ "$SKIP_INSTALL" == "true" ]] && [[ "$INSTALL_PACKAGES" == "true" ]]; then
    dot_error "--skip-install cannot be combined with --install-packages"
    exit 2
  fi

  if [[ -n "$PACKAGE_TIER_OVERRIDE" ]] && [[ "$INSTALL_PACKAGES" != "true" ]]; then
    dot_error "--packages requires --install-packages"
    exit 2
  fi

  if [[ "$SYNC_MODE" == "true" ]] && { [[ "$INSTALL_PACKAGES" == "true" ]] || [[ "$APPLY_MACOS_DEFAULTS" == "true" ]] || [[ "$APPLY_HARDENING" == "true" ]]; }; then
    dot_error "--sync cannot be combined with system provisioning options"
    exit 2
  fi
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
  local required_commands=("git")

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

# Note: create_directory and is_ignored are defined in install/lib.sh
# Note: create_symlink is defined in install/symlinks.sh
# Note: manifest_links/manifest_component_links/manifest_component_exists/
# manifest_components are defined in install/manifest.sh


# Link configuration files from the declarative manifest.
link_configs() {
  dot_title "Linking configuration files"

  if [[ "$VERBOSE" == "true" ]]; then
    dot_info "Profile: $PROFILE ($(get_profile_description "$PROFILE"))"
    dot_info "OS: $OS_TYPE"
  fi

  local links
  if [[ -n "$SYNC_CONFIG" ]]; then
    if ! manifest_component_exists "$SYNC_CONFIG"; then
      dot_error "Config not found: $SYNC_CONFIG"
      exit 1
    fi
    dot_info "Processing $SYNC_CONFIG configuration..."
    links="$(manifest_component_links "$SYNC_CONFIG" "$OS_TYPE")"

    if [[ -z "$links" ]]; then
      dot_warning "No entries for $SYNC_CONFIG on $OS_TYPE; nothing to link"
      return 0
    fi
  else
    local comp
    while IFS= read -r comp; do
      [[ -z "$comp" ]] && continue
      dot_info "Processing $comp configuration..."
    done < <(manifest_components "$PROFILE" "$OS_TYPE")
    links="$(manifest_links "$PROFILE" "$OS_TYPE")"

    if [[ -z "$links" ]]; then
      dot_error "No links selected (missing manifest or empty selection); aborting"
      exit 1
    fi
  fi

  local source dest
  while IFS='|' read -r source dest; do
    [[ -z "$source" ]] && continue
    create_symlink "$source" "$dest"
  done <<<"$links"

  dot_success "Configuration files linked"
}

# Binaries are linked via the manifest `bin` entry in link_configs; this
# remains only to ensure the destination directory exists.
link_binaries() {
  create_directory "$BIN_DEST"
}

# Run explicitly requested system provisioning actions.
run_os_installation() {
  if [[ "$INSTALL_PACKAGES" != "true" ]] && [[ "$APPLY_MACOS_DEFAULTS" != "true" ]] && [[ "$APPLY_HARDENING" != "true" ]]; then
    dot_info "No system provisioning requested; linking configuration only"
    return 0
  fi

  if [[ "$OS_TYPE" != "macos" ]] && { [[ "$APPLY_MACOS_DEFAULTS" == "true" ]] || [[ "$APPLY_HARDENING" == "true" ]]; }; then
    dot_error "--apply-macos-defaults and --harden are available only on macOS"
    exit 2
  fi

  dot_title "Running requested system provisioning"

  case "$OS_TYPE" in
    macos)
      # shellcheck source=install/install-macos.sh
      source "$SCRIPT_DIR/install/install-macos.sh"
      run_macos_provisioning
      ;;
    ubuntu)
      if [[ "$INSTALL_PACKAGES" == "true" ]]; then
        # shellcheck source=install/install-ubuntu.sh
        source "$SCRIPT_DIR/install/install-ubuntu.sh"
        install_ubuntu_packages
      fi
      ;;
  esac
}

# Create only the destinations needed to reconcile links.
create_link_directories() {
  create_directory "$CONFIG_DEST"
  create_directory "$BIN_DEST"
}

# Show summary
show_summary() {
  dot_title "Installation Summary"

  echo "  Profile:        $PROFILE ($(get_profile_description "$PROFILE"))"
  echo "  OS Type:        $OS_TYPE"
  echo "  OS Version:     $OS_VERSION"
  echo "  Config Path:    $CONFIG_DEST"
  echo "  Binary Path:    $BIN_DEST"
  echo "  Packages:       $([[ "$INSTALL_PACKAGES" == "true" ]] && echo "Requested" || echo "Not requested")"
  echo "  Package Tier:   $([[ "$INSTALL_PACKAGES" == "true" ]] && echo "$PACKAGE_TIER" || echo "Not requested")"
  if [[ "$OS_TYPE" == "macos" ]]; then
    echo "  macOS Defaults: $([[ "$APPLY_MACOS_DEFAULTS" == "true" ]] && echo "Requested" || echo "Not requested")"
    echo "  Hardening:      $([[ "$APPLY_HARDENING" == "true" ]] && echo "Requested" || echo "Not requested")"
  fi
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
  MANIFEST_FILE="${MANIFEST_FILE:-$CONFIG_DEST/.dotfiles-manifest}"
  PROFILE_FILE="${PROFILE_FILE:-$CONFIG_DEST/.dotfiles-profile}"

  # The stored profile is the installation intent (same semantics as
  # `dotfiles sync`).  Without an explicit --profile, honor it — otherwise
  # any bootstrap invocation (e.g. `--harden`, `--install-packages`) would
  # silently relink under the minimal default and overwrite the stored file.
  if [[ "$PROFILE_EXPLICIT" != "true" && -f "$PROFILE_FILE" ]]; then
    PROFILE="$(<"$PROFILE_FILE")"
    if ! validate_profile "$PROFILE"; then
      dot_error "Stored profile is invalid: $PROFILE (pass --profile to override)"
      exit 1
    fi
  fi

  # Resolve the package tier now that OS detection and profile validation
  # (in parse_args) have both completed, and before any installer runs.
  PACKAGE_TIER="$(resolve_package_tier "$PROFILE" "$PACKAGE_TIER_OVERRIDE")" || exit 1

  # Export key variables for install scripts and shared libraries
  # (dot_root/CONFIG_DIR are already exported once near the top, before the
  # libraries are sourced; SCRIPT_DIR is readonly, so no need to repeat them)
  export DRY_RUN VERBOSE SCRIPT_DIR OS_TYPE OS_VERSION FORCE PROFILE SYNC_CONFIG
  export INSTALL_PACKAGES APPLY_MACOS_DEFAULTS APPLY_HARDENING PACKAGE_TIER
  export CONFIG_DEST BIN_DEST MANIFEST_FILE PROFILE_FILE

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

    # Clean only manifest-owned broken symlinks first.
    clean_broken_symlinks

    # Create minimal directory structure
    create_directory "$CONFIG_DEST"
    create_directory "$BIN_DEST"

    # Link configurations
    link_configs

    # Link binaries (skip only when syncing one specific config)
    if [[ -z "$SYNC_CONFIG" ]]; then
      link_binaries
    fi

    if [[ -z "$SYNC_CONFIG" && -z "$DRY_RUN" ]]; then
      printf '%s\n' "$PROFILE" >"$PROFILE_FILE"
    fi

    dot_success "Sync completed successfully!"
    echo
    dot_info "Restart your terminal or run: source ~/.zshenv"
  else
    # Normal bootstrap mode
    # Validate environment
    validate_environment

    # Create only link destinations; do not provision unrelated user directories.
    create_link_directories

    # Run OS installation
    run_os_installation

    # Link configurations
    link_configs

    # Link binaries
    link_binaries

    if [[ -z "$SYNC_CONFIG" && -z "$DRY_RUN" ]]; then
      printf '%s\n' "$PROFILE" >"$PROFILE_FILE"
    fi

    # Show summary
    show_summary
  fi
}

# Run the script
parse_args "$@"
main
