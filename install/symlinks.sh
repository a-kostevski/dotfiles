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
            # A manifest can be missing or stale after upgrading from an
            # earlier installer.  A successful reconciliation must repair it.
            [[ -z "${DRY_RUN:-}" ]] && update_manifest "$src" "$dest"
            return 0
        else
            local owner_root="${dot_root:-}"
            if [[ -z "$owner_root" ]]; then
                owner_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
            fi
            if [[ "$current_target" == "$owner_root"/* || "${FORCE:-false}" == "true" ]]; then
                # Stale link into this repo — ours to replace, no backup needed
                dot_info "Updating existing symlink: $dest"
                dry_run rm "$dest"
            else
                # A symlink managed outside this repo gets the same backup
                # treatment as a regular file, so uninstall can restore it
                local backup
                backup=$(unique_backup_path "$dest")
                dot_info "Backing up: $dest -> $backup"
                dry_run mv "$dest" "$backup"
            fi
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
    local all_links="${2:-false}"

    dot_title "Cleaning Broken Symlinks"

    local count=0
    local link src dest
    local owner_root="${dot_root:-}"
    if [[ -z "$owner_root" ]]; then
        owner_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
    fi

    if [[ "$all_links" == "true" ]]; then
        local -a target_dirs=("$HOME/.config" "$HOME/.local/bin")
        local target_dir
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
        local -a home_links=()
        if command -v manifest_home_dests >/dev/null 2>&1; then
            while IFS= read -r link; do
                [[ -n "$link" ]] && home_links+=("$link")
            done < <(manifest_home_dests "${OS_TYPE:-}")
        else
            home_links=("$HOME/.zshenv" "$HOME/.lldbinit")
        fi
        for link in "${home_links[@]}"; do
            [[ -L "$link" && ! -e "$link" ]] || continue
            if [[ -n "$dry_run" ]]; then
                print_status "broken" "Would remove: $link"
            else
                rm -f "$link"
                print_status "ok" "Removed: $link"
            fi
            count=$((count + 1))
        done
    elif [[ -f "$MANIFEST_FILE" ]]; then
        # The manifest is the ownership boundary.  Do not remove arbitrary
        # broken links from a user's config tree during an ordinary sync.
        while IFS='|' read -r _ src dest; do
            [[ "$src" == "$owner_root"/* ]] || continue
            [[ -L "$dest" && ! -e "$dest" ]] || continue
            if [[ -n "$dry_run" ]]; then
                print_status "broken" "Would remove: $dest"
            else
                rm -f "$dest"
                print_status "ok" "Removed: $dest"
            fi
            count=$((count + 1))
        done <"$MANIFEST_FILE"
    fi

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
# -maxdepth here.
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

# Print the newest backup for a destination, ranked by the timestamp (and
# numeric .N collision suffix) embedded in the backup name. mv preserves the
# original file's mtime, so -nt would rank by content age, not backup time.
newest_backup_path() {
    local dest="$1"
    local newest="" newest_key="" b key suffix
    for b in "$dest".backup.*; do
        [[ -e "$b" || -L "$b" ]] || continue
        key="${b##*.backup.}"   # 20260715_101530 or 20260715_101530.3
        if [[ "$key" == *.* ]]; then
            suffix="${key##*.}"
            [[ "$suffix" =~ ^[0-9]+$ ]] || suffix=0
            key="${key%%.*}.$(printf '%06d' "$suffix")"
        else
            key="${key}.000000"
        fi
        if [[ -z "$newest" || "$key" > "$newest_key" ]]; then
            newest="$b"
            newest_key="$key"
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

# Remove one owned symlink; restore its newest backup unless RESTORE=false.
# rc 0 when a link was (or would be) removed, rc 1 when dest is not a link.
# Increments UNINSTALL_RESTORED (caller-initialized) on restore.
uninstall_symlink() {
    local dest="$1"

    [[ -L "$dest" ]] || return 1
    if ! dry_run rm "$dest"; then
        dot_error "Failed to remove: $dest"
        return 1
    fi
    [[ -z "${DRY_RUN:-}" ]] && print_status "ok" "Removed: $dest"

    if [[ "${RESTORE:-true}" == "true" ]]; then
        local backup
        if backup=$(newest_backup_path "$dest"); then
            if [[ -n "${DRY_RUN:-}" ]]; then
                echo "[DRY-RUN] mv $backup $dest"
                UNINSTALL_RESTORED=$((${UNINSTALL_RESTORED:-0} + 1))
            elif restore_newest_backup "$dest"; then
                UNINSTALL_RESTORED=$((${UNINSTALL_RESTORED:-0} + 1))
            fi
        fi
    fi
    return 0
}

# Depth-first removal of empty directories under and including root
prune_empty_dirs() {
    local root="$1"

    [[ -d "$root" ]] || return 0
    if [[ -n "${DRY_RUN:-}" ]]; then
        find "$root" -depth -type d -empty -print 2>/dev/null |
            sed 's/^/[DRY-RUN] rmdir /'
    else
        find "$root" -depth -type d -empty -delete 2>/dev/null
    fi
    return 0
}

# Update manifest file with symlink information (one line per dest: any
# previous entry for the same dest is rewritten away before appending)
update_manifest() {
    local src="$1"
    local dest="$2"
    local timestamp
    timestamp=$(date +"%Y-%m-%d %H:%M:%S")

    local manifest_dir
    manifest_dir=$(dirname "$MANIFEST_FILE")
    [[ ! -d "$manifest_dir" ]] && mkdir -p "$manifest_dir"

    if [[ -f "$MANIFEST_FILE" ]]; then
        local tmp="$MANIFEST_FILE.tmp.$$"
        awk -F'|' -v d="$dest" '$3 != d' "$MANIFEST_FILE" >"$tmp"
        mv "$tmp" "$MANIFEST_FILE"
    fi
    echo "${timestamp}|${src}|${dest}" >>"$MANIFEST_FILE"
}

# Rewrite the manifest without the given destinations
remove_manifest_entries() {
    [[ -f "$MANIFEST_FILE" ]] || return 0
    [[ $# -gt 0 ]] || return 0

    local tmp="$MANIFEST_FILE.tmp.$$"
    printf '%s\n' "$@" |
        awk -F'|' 'NR == FNR { drop[$0] = 1; next } !($3 in drop)' \
            - "$MANIFEST_FILE" >"$tmp"
    mv "$tmp" "$MANIFEST_FILE"
}

