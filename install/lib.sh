#!/usr/bin/env bash

# Shared Library for Dotfiles Installation Scripts
# Version: 1.0.0

# Color constants (only set if not already defined)
if [[ -z "${COLOR_HEADER:-}" ]]; then
    readonly COLOR_HEADER="\033[1;36m"
    readonly COLOR_INFO="\033[34m"
    readonly COLOR_ERROR="\033[31m"
    readonly COLOR_SUCCESS="\033[32m"
    readonly COLOR_WARNING="\033[33m"
    readonly COLOR_RESET="\033[0m"
fi

# Output functions
dot_title() {
    printf "\n${COLOR_HEADER}==> %s${COLOR_RESET}\n" "$1"
}

dot_header() {
    printf "${COLOR_HEADER}%s${COLOR_RESET}\n" "$1"
}

dot_info() {
    [[ "${VERBOSE:-false}" == "true" ]] && printf "  ${COLOR_INFO}[INFO]${COLOR_RESET} %s\n" "$1"
}

dot_error() {
    printf "  ${COLOR_ERROR}[ERROR]${COLOR_RESET} %s\n" "$1" >&2
}

dot_success() {
    printf "  ${COLOR_SUCCESS}[OK]${COLOR_RESET} %s\n" "$1"
}

dot_warning() {
    printf "  ${COLOR_WARNING}[WARN]${COLOR_RESET} %s\n" "$1"
}

# Create directory with proper permissions
create_directory() {
    local dir="$1"
    if [[ ! -d "$dir" ]]; then
        dot_info "Creating directory: $dir"
        ${DRY_RUN:-} mkdir -p "$dir"
    fi
}

# Compatibility alias for old scripts
dot_mkdir() {
    create_directory "$@"
}

# Validate file exists before sourcing
validate_file() {
    local file="$1"
    local description="${2:-file}"
    
    if [[ ! -f "$file" ]]; then
        dot_error "$description not found at: $file"
        return 1
    fi
    return 0
}

# Execute command with proper dry-run handling
execute_cmd() {
    local cmd="$*"
    if [[ -n "${DRY_RUN:-}" ]]; then
        echo "[DRY-RUN] $cmd"
    else
        eval "$cmd"
    fi
}

# Safe sudo with timeout
safe_sudo() {
    local timeout="${1:-300}"  # 5 minutes default
    shift
    
    if [[ -n "${DRY_RUN:-}" ]]; then
        echo "[DRY-RUN] sudo $*"
        return 0
    fi
    
    # Request sudo access
    if ! sudo -v; then
        dot_error "Failed to obtain sudo access"
        return 1
    fi
    
    # Execute command with timeout
    timeout "$timeout" sudo "$@"
}

# Check if command exists
command_exists() {
    command -v "$1" &> /dev/null
}

# Get OS-specific home directory default
get_default_home() {
    case "$(uname -s)" in
        Darwin) echo "/Users/$(whoami)" ;;
        Linux)  echo "/home/$(whoami)" ;;
        *)      echo "$HOME" ;;
    esac
}

# Determine architecture-specific Homebrew prefix
get_brew_prefix() {
    if [[ $(uname -m) == "arm64" ]]; then
        echo "/opt/homebrew"
    else
        echo "/usr/local"
    fi
}