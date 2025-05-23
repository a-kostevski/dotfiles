#!/usr/bin/env bash

# Determine the appropriate Homebrew prefix based on architecture
if [[ $(uname -m) == "arm64" ]]; then
  BREW_PREFIX="/opt/homebrew"
else
  BREW_PREFIX="/usr/local"
fi

# Install Homebrew if not present
install_homebrew() {
  if ! command -v brew >/dev/null; then
    dot_info "Installing Homebrew..."
    NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" || {
      dot_error "Failed to install Homebrew"
      return 1
    }
    
    # Add Homebrew to PATH for the current session
    eval "$($BREW_PREFIX/bin/brew shellenv)"
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
    mkdir -p "$HOME/.config/homebrew"
    cat > "$HOME/.config/homebrew/config" << EOF
export HOMEBREW_NO_ANALYTICS=1
export HOMEBREW_NO_INSECURE_REDIRECT=1
EOF
  fi
}

# Install packages from Brewfile
install_packages() {
  local brewfile="$1"
  if [[ ! -f "$brewfile" ]]; then
    dot_error "Brewfile not found at: $brewfile"
    return 1
  }

  dot_info "Installing Homebrew packages from $brewfile..."
  brew bundle --file="$brewfile" --no-lock || {
    dot_error "Failed to install some Homebrew packages"
    return 1
  }
  dot_success "Installed Homebrew packages"
}

# Ask user which package set to install
select_package_set() {
  local choice
  while true; do
    echo
    dot_header "Select package set to install:"
    echo "1) Minimal - Essential development tools only"
    echo "2) Full - Complete development environment with all tools"
    echo
    read -p "Enter your choice (1/2): " choice
    case "$choice" in
      1) echo "$dot_root/config/homebrew/Brewfile-min"; return 0 ;;
      2) echo "$dot_root/config/homebrew/Brewfile-all"; return 0 ;;
      *) dot_error "Invalid choice. Please enter 1 or 2" ;;
    esac
  done
}

# Main execution
main() {
  install_homebrew || return 1
  configure_homebrew || return 1
  
  local brewfile
  brewfile=$(select_package_set)
  install_packages "$brewfile" || return 1
  
  return 0
}

main "$@" 