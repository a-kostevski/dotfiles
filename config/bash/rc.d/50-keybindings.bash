# Key bindings. Mirrors zsh/rc.d/50-keybindings.zsh using readline.

# Vi mode
set -o vi

# Make Vi mode transitions more obvious: beam cursor in insert mode, block in
# command mode (readline 7.0+ / bash 4.4+).
if (( BASH_VERSINFO[0] > 4 || (BASH_VERSINFO[0] == 4 && BASH_VERSINFO[1] >= 4) )); then
    bind 'set show-mode-in-prompt on'
    bind 'set vi-ins-mode-string "\1\e[5 q\2"'
    bind 'set vi-cmd-mode-string "\1\e[1 q\2"'
fi

# History search
bind -m vi-insert '"\C-r": reverse-search-history'
bind -m vi-insert '"\C-s": forward-search-history'
bind -m vi-command '"?": reverse-search-history'
bind -m vi-command '"/": forward-search-history'

# Beginning/End of line
bind -m vi-insert '"\C-a": beginning-of-line'
bind -m vi-insert '"\C-e": end-of-line'
bind -m vi-command '"\C-a": beginning-of-line'
bind -m vi-command '"\C-e": end-of-line'

# Word movement
bind -m vi-insert '"\C-w": backward-kill-word'
bind -m vi-insert '"\eb": backward-word'
bind -m vi-insert '"\ef": forward-word'

# History navigation: Up/Down (and k/j in command mode) search history for
# commands starting with the typed prefix.
bind -m vi-insert '"\e[A": history-search-backward'
bind -m vi-insert '"\e[B": history-search-forward'
bind -m vi-command '"k": history-search-backward'
bind -m vi-command '"j": history-search-forward'

# Edit command in editor ('v' in command mode is readline's native
# edit-and-execute-command; \C-v mirrors the zsh binding)
bind -m vi-command '"\C-v": edit-and-execute-command'

# Other useful bindings
bind -m vi-insert '"\C-l": clear-screen'
bind -m vi-command '"\C-l": clear-screen'
bind -m vi-insert '"\C-u": unix-line-discard'
bind -m vi-insert '"\C-y": yank'

# Fix backspace in vi mode
bind -m vi-insert '"\C-?": backward-delete-char'
bind -m vi-insert '"\C-h": backward-delete-char'
