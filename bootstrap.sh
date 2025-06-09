#!/usr/bin/env bash

# Unified Bootstrap Script for Dotfiles
# Supports: macOS, Ubuntu/Debian
# Version: 3.0.0

set -e

# Script metadata
readonly SCRIPT_VERSION="3.0.0"
readonly SCRIPT_DATE="2025-06-09"
readonly SCRIPT_NAME=$(basename "$0")
readonly SCRIPT_DIR="$(cd "$(dirname "${0}")" && pwd -P)"

# Configuration constants
readonly DEFAULT_CONFIG_DEST="${HOME}/.config"
readonly DEFAULT_BIN_DEST="${HOME}/.local/bin"
readonly DEFAULT_PROFILE="minimal"

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

# Output functions
dot_title() {
    printf "\n${COLOR_HEADER}==> %s${COLOR_RESET}\n" "$1"
}

dot_header() {
    printf "${COLOR_HEADER}%s${COLOR_RESET}\n" "$1"
}

dot_info() {
    [[ "$VERBOSE" == "true" ]] && printf "  ${COLOR_INFO}[INFO]${COLOR_RESET} %s\n" "$1"
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

# OS detection
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
                    ubuntu|debian)
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
}

# Usage information
usage() {
    cat << EOF
Usage: $SCRIPT_NAME [OPTIONS]

Bootstrap script for installing dotfiles across macOS and Ubuntu.

OPTIONS:
    -p, --profile <profile>     Installation profile: minimal, standard, full (default: minimal)
    -c, --config-dest <path>    Config directory path (default: ~/.config)
    -b, --bin-dest <path>       Binary directory path (default: ~/.local/bin)
    -s, --skip-install          Skip OS-specific installation scripts
    -f, --force                 Force overwrite existing files without backup
    -d, --dry-run               Show what would be done without making changes
    -v, --verbose               Enable verbose output
    -h, --help                  Show this help message

PROFILES:
    minimal:  Essential configs only (zsh, git, tmux)
    standard: Common development tools (+ nvim, basic tools)
    full:     Everything including GUI apps and extras

EXAMPLES:
    # Minimal installation with dry run
    $SCRIPT_NAME --profile minimal --dry-run

    # Standard installation with verbose output
    $SCRIPT_NAME --profile standard --verbose

    # Full installation, skip OS packages
    $SCRIPT_NAME --profile full --skip-install

EOF
    exit 0
}

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -p|--profile)
                PROFILE="${2:-}"
                [[ -z "$PROFILE" ]] && dot_error "Profile requires a value" && exit 1
                shift 2
                ;;
            -c|--config-dest)
                CONFIG_DEST="${2:-}"
                [[ -z "$CONFIG_DEST" ]] && dot_error "Config destination requires a value" && exit 1
                shift 2
                ;;
            -b|--bin-dest)
                BIN_DEST="${2:-}"
                [[ -z "$BIN_DEST" ]] && dot_error "Bin destination requires a value" && exit 1
                shift 2
                ;;
            -s|--skip-install)
                SKIP_INSTALL=true
                shift
                ;;
            -f|--force)
                FORCE=true
                shift
                ;;
            -d|--dry-run)
                DRY_RUN="echo [DRY-RUN]"
                shift
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            -h|--help)
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
        if ! command -v "$cmd" &> /dev/null; then
            dot_error "Required command not found: $cmd"
            exit 1
        fi
    done

    # Validate profile
    case "$PROFILE" in
        minimal|standard|full) ;;
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
        $DRY_RUN mkdir -p "$dir"
    fi
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
            dot_info "Removing existing symlink: $dest"
            $DRY_RUN rm "$dest"
        fi
    fi

    # Handle existing file
    if [[ -e "$dest" ]] && [[ ! -L "$dest" ]]; then
        if [[ "$FORCE" == "true" ]]; then
            dot_warning "Force removing: $dest"
            $DRY_RUN rm -rf "$dest"
        else
            local backup="${dest}.backup.$(date +%Y%m%d_%H%M%S)"
            dot_info "Backing up: $dest -> $backup"
            $DRY_RUN mv "$dest" "$backup"
        fi
    fi

    # Create parent directory if needed
    local parent_dir=$(dirname "$dest")
    [[ ! -d "$parent_dir" ]] && $DRY_RUN mkdir -p "$parent_dir"

    # Create symlink
    dot_info "Linking: $src -> $dest"
    $DRY_RUN ln -sfn "$src" "$dest"
}

# Get config list based on profile and OS
get_config_list() {
    local -a configs=()
    
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
    
    printf '%s\n' "${configs[@]}"
}

# Link configuration files
link_configs() {
    local config_list
    config_list=$(get_config_list)
    
    dot_title "Linking configuration files"
    
    # Special case: zsh needs .zshenv in HOME
    if echo "$config_list" | grep -q "zsh"; then
        create_symlink "$SCRIPT_DIR/config/zsh/zshenv" "$HOME/.zshenv"
    fi
    
    # Special case: lldb needs .lldbinit in HOME (macOS only)
    if [[ "$OS_TYPE" == "macos" ]] && echo "$config_list" | grep -q "lldb"; then
        create_symlink "$SCRIPT_DIR/config/lldb/.lldbinit" "$HOME/.lldbinit"
    fi
    
    # Link each config directory
    while IFS= read -r config; do
        local src="$SCRIPT_DIR/config/$config"
        local dest="$CONFIG_DEST/$config"
        
        if [[ -d "$src" ]]; then
            dot_info "Processing $config configuration..."
            
            # For directories with special handling
            case "$config" in
                zsh)
                    # Already handled .zshenv above, link the rest
                    for item in "$src"/*; do
                        [[ "$(basename "$item")" != "zshenv" ]] && \
                            create_symlink "$item" "$dest/$(basename "$item")"
                    done
                    ;;
                *)
                    # Link all files in the directory
                    while IFS= read -r file; do
                        local rel_path="${file#$src/}"
                        create_symlink "$file" "$dest/$rel_path"
                    done < <(find "$src" -type f -not -name ".DS_Store" 2>/dev/null)
                    ;;
            esac
        fi
    done <<< "$config_list"
    
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
    
    # Link scripts
    local count=0
    while IFS= read -r script; do
        create_symlink "$script" "$BIN_DEST/$(basename "$script")"
        ((count++))
    done < <(find "$SCRIPT_DIR/bin" -type f -not -name ".*" 2>/dev/null)
    
    # Set permissions
    [[ -d "$BIN_DEST" ]] && $DRY_RUN chmod -R 755 "$BIN_DEST"
    
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
                if command -v zsh &> /dev/null && [[ "$SHELL" != *"zsh"* ]]; then
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
    PROFILE="${PROFILE:-$DEFAULT_PROFILE}"
    CONFIG_DEST="${CONFIG_DEST:-$DEFAULT_CONFIG_DEST}"
    BIN_DEST="${BIN_DEST:-$DEFAULT_BIN_DEST}"
    
    # Export key variables for install scripts
    export dot_root="$SCRIPT_DIR"
    export DRY_RUN VERBOSE PROFILE SCRIPT_DIR
    
    # Show header
    dot_header "Dotfiles Bootstrap v${SCRIPT_VERSION}"
    dot_header "OS: ${OS_TYPE} ${OS_VERSION}"
    echo
    
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
}

# Run the script
parse_args "$@"
main