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

# Pick a backup destination that does not clobber an existing backup
# (second-granularity timestamps collide when several files are backed up
# in the same second)
unique_backup_path() {
    local path="$1"
    local base
    base="${path}.backup.$(date +%Y%m%d_%H%M%S)"
    local candidate="$base"
    local i=1
    while [[ -e "$candidate" || -L "$candidate" ]]; do
        candidate="$base.$i"
        i=$((i + 1))
    done
    echo "$candidate"
}

# Create symlink with backup
create_symlink() {
    local src="$1"
    local dest="$2"

    # Source must exist
    [[ ! -e "$src" ]] && dot_error "Source not found: $src" && return 1

    # Handle existing symlink
    if [[ -L "$dest" ]]; then
        local current_target
        current_target=$(readlink "$dest")
        if [[ "$current_target" == "$src" ]]; then
            # Only show in verbose mode - symlink already correct
            [[ "${VERBOSE:-false}" == "true" ]] && dot_info "Already linked: $dest"
            return 0
        else
            # Always show - symlink is being updated
            dot_info "Updating existing symlink: $dest"
            dry_run rm "$dest"
        fi
    # Handle existing file (non-symlink)
    elif [[ -e "$dest" ]]; then
        if [[ "${FORCE:-false}" == "true" ]]; then
            # Always show - force removing existing file
            dot_warning "Force removing: $dest"
            dry_run rm -rf "$dest"
        else
            # Always show - backing up existing file
            local backup
            backup=$(unique_backup_path "$dest")
            dot_info "Backing up: $dest -> $backup"
            dry_run mv "$dest" "$backup"
        fi
    fi

    # Create parent directory if needed
    local dest_dir
    dest_dir=$(dirname "$dest")
    if [[ ! -d "$dest_dir" ]]; then
        # If path exists but is not a directory, back it up
        if [[ -e "$dest_dir" ]]; then
            local backup
            backup=$(unique_backup_path "$dest_dir")
            dot_warning "Path exists but is not a directory: $dest_dir"
            dot_info "Backing up: $dest_dir -> $backup"
            dry_run mv "$dest_dir" "$backup"
        fi
        # Only show in verbose mode - creating parent directory
        [[ "${VERBOSE:-false}" == "true" ]] && dot_info "Creating directory: $dest_dir"
        dry_run mkdir -p "$dest_dir"
    fi

    # Create symlink
    # Only show in verbose mode if symlink didn't exist before
    # (updates/backups are already shown above)
    if [[ ! -L "$dest" ]] && [[ ! -e "$dest" ]] && [[ "${VERBOSE:-false}" == "true" ]]; then
        dot_info "Linking: $src -> $dest"
    fi
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

    local count=0
    local target_dir link

    # Check each target directory
    # (process substitution keeps the counter in the main shell)
    for target_dir in "${target_dirs[@]}"; do
        [[ ! -d "$target_dir" ]] && continue

        while IFS= read -r link; do
            [[ -z "$link" ]] && continue
            if [[ -n "$dry_run" ]]; then
                print_status "broken" "Would remove: $link"
            else
                rm -f "$link"
                print_status "ok" "Removed: $link"
            fi
            count=$((count + 1))
        done < <(find "$target_dir" -type l ! -exec test -e {} \; -print 2>/dev/null || true)
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
            count=$((count + 1))
        fi
    done

    if [[ $count -gt 0 ]]; then
        if [[ -n "$dry_run" ]]; then
            dot_success "Would remove $count broken symlink(s)"
        else
            dot_success "Removed $count broken symlink(s)"
        fi
    else
        dot_success "No broken symlinks found"
    fi

    return 0
}

# Is this path a symlink whose target lies under owner_root?
is_owned_symlink() {
    local link="$1"
    local owner="$2"

    [[ -L "$link" ]] || return 1
    local target
    target=$(readlink "$link" 2>/dev/null) || return 1
    [[ "$target" == "$owner"/* ]]
}

# Print all symlinks under a directory (unbounded depth) whose target lies
# under owner_root. Links are created per-file at arbitrary depth, so no
# -maxdepth here (unlike the detection-only scan in get_synced_configs).
find_owned_symlinks() {
    local dir="$1"
    local owner="$2"

    [[ -d "$dir" ]] || return 0
    local link
    while IFS= read -r link; do
        is_owned_symlink "$link" "$owner" && printf '%s\n' "$link"
    done < <(find "$dir" -type l 2>/dev/null)
    return 0
}

# Print the mtime-newest backup for a destination, if any.
# (The .N collision suffix breaks lexical ordering, so compare with -nt.)
newest_backup_path() {
    local dest="$1"
    local newest="" b
    for b in "$dest".backup.*; do
        [[ -e "$b" || -L "$b" ]] || continue
        if [[ -z "$newest" || "$b" -nt "$newest" ]]; then
            newest="$b"
        fi
    done
    [[ -n "$newest" ]] || return 1
    printf '%s\n' "$newest"
}

# Move the newest backup back into place. Never overwrites.
restore_newest_backup() {
    local dest="$1"
    local backup
    backup=$(newest_backup_path "$dest") || return 1
    if [[ -e "$dest" || -L "$dest" ]]; then
        dot_warning "Not restoring $backup: $dest already exists"
        return 1
    fi
    if ! mv "$backup" "$dest"; then
        dot_error "Failed to restore: $backup -> $dest"
        return 1
    fi
    print_status "ok" "Restored: $dest (from ${backup##*/})"

    # Older backups are left in place and reported
    local other
    for other in "$dest".backup.*; do
        [[ -e "$other" || -L "$other" ]] || continue
        print_status "info" "Older backup kept: $other"
    done
}

# Update manifest file with symlink information
update_manifest() {
    local src="$1"
    local dest="$2"
    local timestamp
    timestamp=$(date +"%Y-%m-%d %H:%M:%S")

    # Create manifest directory if needed
    local manifest_dir
    manifest_dir=$(dirname "$MANIFEST_FILE")
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

# Get list of configs that are currently synced (have symlinks pointing to dotfiles)
get_synced_configs() {
    local config_dest="${1:-$HOME/.config}"
    local config_src="${CONFIG_DIR:-$dot_root/config}"
    local -a synced=()

    # Check ~/.config subdirectories for symlinks pointing to our config source
    for config_dir in "$config_dest"/*/; do
        [[ -d "$config_dir" ]] || continue
        local config_name
        config_name=$(basename "$config_dir")

        # Check if any symlink in this dir points back to our config source
        local found=false
        while IFS= read -r link; do
            local target
            target=$(readlink "$link" 2>/dev/null || true)
            if [[ "$target" == "$config_src/$config_name"* ]]; then
                found=true
                break
            fi
        done < <(find "$config_dir" -maxdepth 2 -type l 2>/dev/null)

        [[ "$found" == "true" ]] && synced+=("$config_name")
    done

    # Check special home-directory symlinks (zsh, lldb)
    if [[ -L "$HOME/.zshenv" ]]; then
        local target
        target=$(readlink "$HOME/.zshenv" 2>/dev/null || true)
        if [[ "$target" == "$config_src/zsh"* ]]; then
            # Add zsh if not already detected
            local has_zsh=false
            for s in "${synced[@]}"; do [[ "$s" == "zsh" ]] && has_zsh=true; done
            [[ "$has_zsh" == "false" ]] && synced+=("zsh")
        fi
    fi

    if [[ -L "$HOME/.lldbinit" ]]; then
        local target
        target=$(readlink "$HOME/.lldbinit" 2>/dev/null || true)
        if [[ "$target" == "$config_src/lldb"* ]]; then
            local has_lldb=false
            for s in "${synced[@]}"; do [[ "$s" == "lldb" ]] && has_lldb=true; done
            [[ "$has_lldb" == "false" ]] && synced+=("lldb")
        fi
    fi

    printf '%s\n' "${synced[@]}" | sort -u
}

# Check if any binaries are currently synced
has_synced_binaries() {
    local bin_dest="${1:-$HOME/.local/bin}"
    local bin_src="${dot_root:-}/bin"

    [[ ! -d "$bin_dest" ]] && return 1

    while IFS= read -r link; do
        local target
        target=$(readlink "$link" 2>/dev/null || true)
        if [[ "$target" == "$bin_src"* ]]; then
            return 0
        fi
    done < <(find "$bin_dest" -maxdepth 1 -type l 2>/dev/null)

    return 1
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
        
        local basename
        basename=$(basename "$file")
        
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
    local ok_count broken_count missing_count
    ok_count=$(cat "$temp_dir/ok_count")
    broken_count=$(cat "$temp_dir/broken_count")
    missing_count=$(cat "$temp_dir/missing_count")
    
    rm -rf "$temp_dir"
    
    echo "$ok_count|$broken_count|$missing_count"
}