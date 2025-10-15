#!/usr/bin/env bash

# Symlink Management Module for Dotfiles
# Version: 1.0.0

# Source shared library if not already loaded
if [[ -z "${dot_title:-}" ]]; then
    source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
fi

# Configuration constants
MANIFEST_FILE="${MANIFEST_FILE:-$HOME/.config/.dotfiles-manifest}"
CACHE_DIR="${CACHE_DIR:-$HOME/.cache/dotfiles}"

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
        if [[ "${FORCE:-false}" == "true" ]]; then
            dot_warning "Force removing: $dest"
            dry_run rm -rf "$dest"
        else
            local backup="${dest}.backup.$(date +%Y%m%d_%H%M%S)"
            dot_info "Backing up: $dest -> $backup"
            dry_run mv "$dest" "$backup"
        fi
    fi

    # Create parent directory if needed
    local dest_dir=$(dirname "$dest")
    if [[ ! -d "$dest_dir" ]]; then
        # If path exists but is not a directory, back it up
        if [[ -e "$dest_dir" ]]; then
            local backup="${dest_dir}.backup.$(date +%Y%m%d_%H%M%S)"
            dot_warning "Path exists but is not a directory: $dest_dir"
            dot_info "Backing up: $dest_dir -> $backup"
            dry_run mv "$dest_dir" "$backup"
        fi
        dot_info "Creating directory: $dest_dir"
        dry_run mkdir -p "$dest_dir"
    fi

    # Create symlink
    dot_info "Linking: $src -> $dest"
    dry_run ln -sfn "$src" "$dest"
    
    # Update manifest
    if [[ -z "${DRY_RUN:-}" ]]; then
        update_manifest "$src" "$dest"
    fi
}

# Check symlink status
check_symlink() {
    local expected_src="$1"
    local dest="$2"
    local show_details="${3:-true}"

    if [[ -L "$dest" ]]; then
        local target
        target=$(readlink "$dest")
        if [[ "$target" == "$expected_src" ]]; then
            if [[ -e "$dest" ]]; then
                [[ "$show_details" == "true" ]] && print_status "ok" "$dest -> $expected_src"
                return 0
            else
                [[ "$show_details" == "true" ]] && print_status "broken" "$dest -> $expected_src (target missing)"
                return 1
            fi
        else
            [[ "$show_details" == "true" ]] && print_status "broken" "$dest -> $target (wrong target, should be $expected_src)"
            return 1
        fi
    else
        [[ "$show_details" == "true" ]] && print_status "missing" "$dest (not linked)"
        return 2
    fi
}

# Clean broken symlinks in directories
clean_broken_symlinks() {
    local dry_run="${1:-${DRY_RUN:-}}"
    local -a target_dirs=(
        "$HOME/.config"
        "$HOME/.local/bin"
    )
    
    dot_title "Cleaning Broken Symlinks"
    
    local temp_file=$(mktemp)
    echo "0" > "$temp_file"
    
    # Check each target directory
    for target_dir in "${target_dirs[@]}"; do
        # Skip if directory doesn't exist
        [[ ! -d "$target_dir" ]] && continue
        
        # Use lnclean if available
        if command -v lnclean &>/dev/null; then
            dot_info "Using lnclean to clean broken symlinks in $target_dir"
            if [[ -n "$dry_run" ]]; then
                find "$target_dir" -type l ! -exec test -e {} \; -print 2>/dev/null | while read -r link; do
                    print_status "broken" "Would remove: $link"
                    echo $(($(cat "$temp_file") + 1)) > "$temp_file"
                done
            else
                lnclean "$target_dir" 2>/dev/null || true
            fi
        else
            # Fallback to find command
            # Use process substitution to avoid subshell issues with set -e
            while IFS= read -r link; do
                if [[ -n "$dry_run" ]]; then
                    print_status "broken" "Would remove: $link"
                else
                    rm -f "$link"
                    print_status "ok" "Removed: $link"
                fi
                echo $(($(cat "$temp_file") + 1)) > "$temp_file"
            done < <(find "$target_dir" -type l ! -exec test -e {} \; -print 2>/dev/null || true)
        fi
    done
    
    # Also clean home directory symlinks
    for link in "$HOME/.zshenv" "$HOME/.lldbinit"; do
        if [[ -L "$link" ]] && [[ ! -e "$link" ]]; then
            if [[ -n "$dry_run" ]]; then
                print_status "broken" "Would remove: $link"
            else
                rm -f "$link"
                print_status "ok" "Removed: $link"
            fi
            echo $(($(cat "$temp_file") + 1)) > "$temp_file"
        fi
    done
    
    local count=$(cat "$temp_file")
    rm -f "$temp_file"
    
    if [[ $count -gt 0 ]]; then
        dot_success "Found $count broken symlinks"
    else
        dot_success "No broken symlinks found"
    fi
    
    return 0
}

# Update manifest file with symlink information
update_manifest() {
    local src="$1"
    local dest="$2"
    local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    
    # Create manifest directory if needed
    local manifest_dir=$(dirname "$MANIFEST_FILE")
    [[ ! -d "$manifest_dir" ]] && mkdir -p "$manifest_dir"
    
    # Add entry to manifest
    echo "${timestamp}|${src}|${dest}" >> "$MANIFEST_FILE"
}

# Read manifest and return symlink mappings
read_manifest() {
    local manifest="${1:-$MANIFEST_FILE}"
    
    if [[ -f "$manifest" ]]; then
        cat "$manifest"
    fi
}

# Get all expected symlinks for a config
get_config_symlinks() {
    local config_name="$1"
    local config_dir="$2"
    local dest_base="${3:-$HOME/.config}"
    
    # Special cases for certain configs
    case "$config_name" in
        zsh)
            # zshenv goes to HOME
            if [[ -f "$config_dir/zshenv" ]]; then
                echo "$config_dir/zshenv|$HOME/.zshenv"
            fi
            ;;
        lldb)
            # .lldbinit goes to HOME (macOS only)
            if [[ "${OS_TYPE:-}" == "macos" ]] && [[ -f "$config_dir/.lldbinit" ]]; then
                echo "$config_dir/.lldbinit|$HOME/.lldbinit"
            fi
            ;;
    esac
    
    # Regular config files
    find "$config_dir" -type f 2>/dev/null | while read -r file; do
        # Skip ignored files
        if is_ignored "$file"; then
            continue
        fi
        
        local basename=$(basename "$file")
        
        # Skip special cases already handled
        if [[ "$config_name" == "zsh" && "$basename" == "zshenv" ]]; then
            continue
        fi
        
        # Get relative path and construct destination
        local rel_path="${file#$config_dir/}"
        local dest="$dest_base/$config_name/$rel_path"
        
        echo "$file|$dest"
    done
}

# Check health of all symlinks for given configs
check_symlink_health() {
    local -a configs=("$@")
    local config_base="${CONFIG_DIR:-$dot_root/config}"
    
    # Use temp files to track counts
    local temp_dir
    temp_dir=$(mktemp -d)
    echo "0" >"$temp_dir/ok_count"
    echo "0" >"$temp_dir/broken_count"
    echo "0" >"$temp_dir/missing_count"
    
    for config in "${configs[@]}"; do
        local config_path="$config_base/$config"
        [[ ! -d "$config_path" ]] && continue
        
        get_config_symlinks "$config" "$config_path" | while IFS='|' read -r src dest; do
            if check_symlink "$src" "$dest" false; then
                echo $(($(cat "$temp_dir/ok_count") + 1)) >"$temp_dir/ok_count"
            else
                local status=$?
                if [[ $status -eq 1 ]]; then
                    echo $(($(cat "$temp_dir/broken_count") + 1)) >"$temp_dir/broken_count"
                else
                    echo $(($(cat "$temp_dir/missing_count") + 1)) >"$temp_dir/missing_count"
                fi
            fi
        done
    done
    
    # Return counts
    local ok_count=$(cat "$temp_dir/ok_count")
    local broken_count=$(cat "$temp_dir/broken_count")
    local missing_count=$(cat "$temp_dir/missing_count")
    
    rm -rf "$temp_dir"
    
    echo "$ok_count|$broken_count|$missing_count"
}