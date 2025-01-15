# Key mappings
typeset -gA keys=(
    Up '^[[A'
    Down '^[[B'
    Right '^[[C'
    Left '^[[D'
    Shift+Tab '^[[Z'
    Backspace $'\x7f'
)

# Vi mode settings
bindkey -v
export KEYTIMEOUT=1  # Reduce mode switch delay

# Make Vi mode transitions more obvious
function zle-keymap-select {
  if [[ ${KEYMAP} == vicmd ]] || [[ $1 = 'block' ]]; then
      echo -ne '\e[1 q'  # Block cursor
  elif [[ ${KEYMAP} == main ]] || [[ ${KEYMAP} == viins ]] || [[ ${KEYMAP} = '' ]] || [[ $1 = 'beam' ]]; then
      echo -ne '\e[5 q'  # Beam cursor
  fi
}
zle -N zle-keymap-select

# Ensure beam cursor on startup
echo -ne '\e[5 q'

# Use beam cursor for each new prompt
preexec() { echo -ne '\e[5 q' }

# History search
bindkey -M vicmd '?' history-incremental-search-backward
bindkey -M vicmd '/' history-incremental-search-forward
bindkey -M viins '^R' history-incremental-pattern-search-backward
bindkey -M viins '^S' history-incremental-pattern-search-forward

# Beginning/End of line
bindkey -M vicmd '^A' beginning-of-line
bindkey -M vicmd '^E' end-of-line
bindkey -M viins '^A' beginning-of-line
bindkey -M viins '^E' end-of-line

# Word movement
bindkey -M vicmd '^W' backward-kill-word
bindkey -M viins '^W' backward-kill-word
bindkey -M vicmd '^[b' backward-word
bindkey -M vicmd '^[f' forward-word
bindkey -M viins '^[b' backward-word
bindkey -M viins '^[f' forward-word

# History navigation
bindkey -M viins "${keys[Up]}" history-beginning-search-backward
bindkey -M viins "${keys[Down]}" history-beginning-search-forward
bindkey -M vicmd "k" history-beginning-search-backward
bindkey -M vicmd "j" history-beginning-search-forward

# Edit command in editor
autoload -Uz edit-command-line
zle -N edit-command-line
bindkey -M vicmd '^V' edit-command-line
bindkey -M viins '^V' edit-command-line

# Other useful bindings
bindkey -M viins '^L' clear-screen
bindkey -M vicmd '^L' clear-screen
bindkey -M viins '^U' backward-kill-line
bindkey -M viins '^Y' yank
bindkey -M vicmd 'Y' vi-yank-eol
bindkey -M vicmd 'y' vi-yank
bindkey -M vicmd 'dd' kill-whole-line

# Fix backspace in vi mode
bindkey -M viins '^?' backward-delete-char
bindkey -M viins '^H' backward-delete-char

# Menu select bindings
bindkey -M menuselect 'h' vi-backward-char
bindkey -M menuselect 'k' vi-up-line-or-history
bindkey -M menuselect 'j' vi-down-line-or-history
bindkey -M menuselect 'l' vi-forward-char
bindkey -M menuselect '^xg' clear-screen
bindkey -M menuselect '^xi' vi-insert
bindkey -M menuselect '^xh' accept-and-hold
bindkey -M menuselect '^xn' accept-and-infer-next-history
bindkey -M menuselect '^xu' undo
bindkey -M menuselect "${keys[Shift+Tab]}" reverse-menu-complete
bindkey -M menuselect '^C' reset-prompt

# Ensure proper delete key behavior
bindkey -M vicmd '^[[3~' delete-char
bindkey -M viins '^[[3~' delete-char
