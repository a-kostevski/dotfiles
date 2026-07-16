# Programmable completion. Mirrors the intent of zsh/rc.d/30-completions.zsh
# using bash-completion and readline settings.

# Load bash-completion (Homebrew keg on macOS, system package on Linux).
# bash-completion v2 lazy-loads per-command completions, so this stays cheap.
if [[ -n "${HOMEBREW_PREFIX:-}" && -r "$HOMEBREW_PREFIX/etc/profile.d/bash_completion.sh" ]]; then
    source "$HOMEBREW_PREFIX/etc/profile.d/bash_completion.sh"
elif [[ -r /usr/share/bash-completion/bash_completion ]]; then
    source /usr/share/bash-completion/bash_completion
elif [[ -r /etc/bash_completion ]]; then
    source /etc/bash_completion
fi

# --- Readline completion behavior ---
bind 'set completion-ignore-case on'       # Case-insensitive completion.
bind 'set mark-symlinked-directories on'   # Add a slash to completed dir symlinks.
bind 'set show-all-if-ambiguous on'        # First Tab lists matches; never cycle blindly.
bind 'set show-all-if-unmodified on'
bind 'set page-completions off'            # List matches instead of paging them.
bind 'set completion-query-items 200'      # Ask before listing more than 200 matches.
bind 'set colored-stats on'                # Color completion candidates by file type.

# readline 7.0+ (bash 4.4+) settings
if (( BASH_VERSINFO[0] > 4 || (BASH_VERSINFO[0] == 4 && BASH_VERSINFO[1] >= 4) )); then
    bind 'set colored-completion-prefix on' # Highlight the common prefix.
fi
