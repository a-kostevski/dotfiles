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
   printf "  ${COLOR_INFO}[INFO]${COLOR_RESET} %s\n" "$1"
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

# Check if a file should be ignored based on .gitignore patterns
is_ignored() {
    local file="$1"
    local base_dir="${2:-$dot_root}"
    local rel_path="${file#$base_dir/}"
    
    # Use git check-ignore if we're in a git repo
    if [[ -d "$base_dir/.git" ]] && command -v git &>/dev/null; then
        git -C "$base_dir" check-ignore -q "$rel_path" 2>/dev/null
        return $?
    fi
    
    # Fallback: manually check common patterns
    local basename
    basename=$(basename "$file")
    
    # Check common ignore patterns
    case "$basename" in
        .DS_Store|*.local|*.claude|Brewfile*.lock.json)
            return 0
            ;;
    esac
    
    return 1
}

# Dry run command execution (improved version)
dry_run() {
    if [[ -n "${DRY_RUN:-}" ]]; then
        echo "[DRY-RUN] $*"
    else
        "$@"
    fi
}

# Print colored status messages
print_status() {
    local status="$1"
    local message="$2"
    case "$status" in
        ok) printf "  ${COLOR_SUCCESS}✓${COLOR_RESET} %s\n" "$message" ;;
        broken) printf "  ${COLOR_ERROR}✗${COLOR_RESET} %s\n" "$message" ;;
        missing) printf "  ${COLOR_WARNING}?${COLOR_RESET} %s\n" "$message" ;;
        info) printf "  ${COLOR_INFO}ℹ${COLOR_RESET} %s\n" "$message" ;;
        *) printf "  %s\n" "$message" ;;
    esac
}

# OS detection function
detect_os() {
    case "$(uname -s)" in
        Darwin)
            OS_TYPE="macos"
            OS_VERSION=$(sw_vers -productVersion)
            ;;
        Linux)
            if [[ -f /etc/os-release ]]; then
                . /etc/os-release
                case "$ID" in
                    ubuntu | debian)
                        OS_TYPE="ubuntu"
                        OS_VERSION="$VERSION_ID"
                        ;;
                    *)
                        OS_TYPE="unsupported"
                        ;;
                esac
            else
                OS_TYPE="unsupported"
            fi
            ;;
        *)
            OS_TYPE="unsupported"
            ;;
    esac
    
    # Export for use in other scripts
    export OS_TYPE OS_VERSION
}

# Resolve symlink to actual path (cross-platform)
resolve_path() {
    local path="$1"
    
    if [[ "$(uname)" == "Darwin" ]]; then
        # macOS: Use a different approach
        while [[ -L "$path" ]]; do
            local dir="$(cd "$(dirname "$path")" && pwd)"
            path="$(readlink "$path")"
            [[ "$path" != /* ]] && path="$dir/$path"
        done
        echo "$(cd "$(dirname "$path")" && pwd)/$(basename "$path")"
    else
        # Linux: Use readlink -f
        readlink -f "$path"
    fi
}
