# --- Completion options ---
setopt always_last_prompt   # Always put the prompt on the last line.
setopt always_to_end        # Move the cursor to the end of the line when accepting a completion.
setopt auto_menu            # Automatically use menu completion.
setopt auto_param_slash     # When completing a directory name, add a slash.
setopt auto_remove_slash    # Intelligently remove the trailing slash from a completed directory name.
setopt complete_aliases     # Complete aliases when the _expand_alias completer is used.
setopt complete_in_word     # Complete from both ends of a word.
setopt no_case_glob         # Perform case-insensitive globbing.
setopt no_flow_control      # Disable flow control.
setopt no_list_beep         # Don't beep.
setopt list_packed          # Packed list.
setopt list_types           # List all types when listing completions.
setopt path_dirs            # Perform path search even for command names with slashes.

setopt menu_complete      # Do not autoselect the first completion entry.

zmodload zsh/complist
autoload -Uz compinit

ZSH_COMPDUMP=$XDG_CACHE_HOME/zsh/zcompdump

# Check if compdump needs regeneration (once per day)
# Compare day of year to avoid regenerating multiple times per day
if [[ -f $ZSH_COMPDUMP ]]; then
    local current_day=$(get_day_of_year)
    local dump_day

    if is_macos; then
        dump_day=$(stat -f '%Sm' -t '%j' "$ZSH_COMPDUMP" 2>/dev/null || echo "0")
    else
        # On Linux, convert modification time to day of year
        local mtime=$(stat -c '%Y' "$ZSH_COMPDUMP" 2>/dev/null || echo "0")
        dump_day=$(date -d "@$mtime" +'%j' 2>/dev/null || echo "0")
    fi

    if [[ "$current_day" != "$dump_day" ]]; then
        compinit -d $ZSH_COMPDUMP
        touch $ZSH_COMPDUMP
    else
        compinit -C -d $ZSH_COMPDUMP
    fi
else
    compinit -d $ZSH_COMPDUMP
    touch $ZSH_COMPDUMP
fi
unset ZSH_COMPDUMP
_comp_options+=(globdots) 

# --- Set up ---
# Define completers
zstyle ':completion:*' completer _expand _complete _match _approximate

# General completion settings
zstyle ':completion:*' menu select
zstyle ':completion:*' use-cache on
zstyle ':completion:*' cache-path $XDG_CACHE_HOME/zsh/zcompcache

# --- Style ---
# Colors
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS:-}"

# Groups
zstyle ':completion:*' group-name ''
zstyle ':completion:*:matches' group true
zstyle ':completion:*:*:-command-:*:*' group-order aliases commands builtins functions 

# Descriptions
zstyle ':completion:*:descriptions' format '%B-- %d --%b'
zstyle ':completion:*:*:*:*:corrections' format '%F{yellow}!- %d (errors: %e) -!%f'
zstyle ':completion:*:*:*:*:descriptions' format '%F{blue}-- %D %d --%f'
zstyle ':completion:*:*:*:*:messages' format ' %F{purple} -- %d --%f'
zstyle ':completion:*:*:*:*:warnings' format ' %F{red}-- no matches found --%f'

# --- Behavior ---
# Case-insensitive matching
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Z}' 'r:|[._-]=* r:|=*' 'l:|=* r:|=*'
zstyle ':completion:*' keep-prefix true

# Filtering unavailable commands.
zstyle ':completion:*:functions' ignored-patterns '(_*|pre(cmd|exec))'
# Filter duplicate entries
zstyle ':completion:*' ignore-duplicates true
# Filter junk files
zstyle ':completion:*' file-ignore '*.o' '*.pyc' '*~' '#*#' '.DS_Store' '*.class' '*.jar' '*.war' '*.ear' '*.zip' '*.tar' '*.gz' '*.tgz' '*.rar' '*.7z' '*.exe' '*.dll' '*.so' '*.dylib' '*.a' '*.lib' '*.obj' '*.o' '*.obj' '*.pdb' '*.idb' '*.ilk' '*.exp' '*.suo' '*.sdf' '*.opensdf' '*.ncb' '*.plg' '*.bsc' '*.aps' '*.res' '*.opt' '*.pch' '*.ipch' '*.iobj' '*.ilk' '*.log' '*.tlog' '*.lastbuildstate' '*.bin' '*.bak' '*.tmp' '*.temp' '*.old' '*.orig' '*.swp' '*.bak' '*.BAK' '*.tmp' '*.TMP' '*.temp' '*.TEMP' '*.old' '*.OLD' '*.orig' '*.ORIG' '*.swp' '*.swo' '*.swn' '*.DS_Store'

# Approximate completion
zstyle ':completion:*:approximate:*' max-errors 1 numeric

# -- Directories --
# Dont display all tags
zstyle ':completion:*:*:cd:*' tag-order local-directories directory-stack path-directories
# Group ordering
zstyle ':completion:*:-tilde-:*' group-order 'named-directories' 'path-directories' 'users' 'expand'
# Expand tilde
zstyle ':completion:*' expand true
# Squeeze multiple slashes
zstyle ':completion:*' squeeze-slashes true

# Autocomplete options for cd instead of directory stack
zstyle ':completion:*' complete-options true
zstyle ':completion:*' file-sort modification

# --- Users ---
zstyle ':completion:*:*:*:users' ignored-patterns adm daemon bin sys sync games man lp mail news uucp proxy www-data backup list irc gnats nobody systemd-timesync systemd-network systemd-resolve systemd-bus-proxy syslog messagebus _apt uuidd tcpdump avahi-autoipd usbmux dnsmasq rtkit cups-pk-helper speech-dispatcher colord saned hplip pulse geoclue gnome-initial-setup gdm flatpak

