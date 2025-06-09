#!/usr/bin/env bash

# Source shared library
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh" 2>/dev/null || source "$(pwd)/install/lib.sh"

# Get the appropriate Homebrew prefix
BREW_PREFIX=$(get_brew_prefix)

# Install Homebrew if not present
install_homebrew() {
  if ! command_exists brew; then
    dot_info "Installing Homebrew..."
    if execute_cmd 'NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'; then
      # Add Homebrew to PATH for the current session
      [[ -z "$DRY_RUN" ]] && eval "$($BREW_PREFIX/bin/brew shellenv)"
    else
      dot_error "Failed to install Homebrew"
      return 1
    fi
  else
    dot_info "Homebrew is already installed"
  fi
}

# Configure Homebrew settings
configure_homebrew() {
  # Disable analytics
  export HOMEBREW_NO_ANALYTICS=1
  export HOMEBREW_NO_INSECURE_REDIRECT=1

  # Save the settings permanently
  if [[ ! -f "$HOME/.config/homebrew/config" ]]; then
    execute_cmd "mkdir -p '$HOME/.config/homebrew'"
    if [[ -z "$DRY_RUN" ]]; then
      cat >"$HOME/.config/homebrew/config" <<EOF
export HOMEBREW_NO_ANALYTICS=1
export HOMEBREW_NO_INSECURE_REDIRECT=1
EOF
    else
      echo "[DRY-RUN] cat >'$HOME/.config/homebrew/config'"
    fi
  fi
}

# Install packages from Brewfile
install_packages() {
  local brewfile="$1"
  local profile="${PROFILE:-minimal}"
  local brewfile_type="minimal"
  
  [[ "$brewfile" == *"Brewfile-all" ]] && brewfile_type="full"
  
  dot_info "Using $brewfile_type Brewfile for $profile profile"
  dot_info "Installing Homebrew packages from $brewfile..."
  
  if ! validate_file "$brewfile" "Brewfile"; then
    return 1
  fi

  if execute_cmd "brew bundle --file='$brewfile' --no-lock"; then
    dot_success "Installed Homebrew packages"
  else
    dot_error "Failed to install some Homebrew packages"
    return 1
  fi
}

# Get Brewfile based on profile
get_brewfile_for_profile() {
  local profile="${PROFILE:-minimal}"
  
  case "$profile" in
    minimal|standard)
      echo "$dot_root/config/homebrew/Brewfile-min"
      ;;
    full)
      echo "$dot_root/config/homebrew/Brewfile-all"
      ;;
    *)
      dot_warning "Unknown profile '$profile', defaulting to minimal" >&2
      echo "$dot_root/config/homebrew/Brewfile-min"
      ;;
  esac
}

# Main execution
main() {
  install_homebrew || return 1
  configure_homebrew || return 1

  local brewfile
  brewfile=$(get_brewfile_for_profile)
  install_packages "$brewfile" || return 1

  return 0
}

main "$@"

