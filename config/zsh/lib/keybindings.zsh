typeset -gA keys=(
    Up '^[[A'
    Down '^[[B'
    Right '^[[C'
    Left '^[[D'
    Shift+Tab '^[[Z'
    Backspace $'\x7f'
)

bindkey -v

bindkey -M viins "${keys[Up]}" history-beginning-search-backward
bindkey -M viins "${keys[Down]}" history-beginning-search-forward

bindkey -M viins '^X^Z' '%-^M'
bindkey -M viins '^[e' expand-cmd-path
bindkey -M viins '^[^I' reverse-menu-complete
bindkey -M viins '^X^N' accept-and-infer-next-history
bindkey -M viins '^W' backward-kill-word # Default behavior in Vi mode
bindkey -M viins '^I' complete-word

# Map Ctrl+L to clear-screen in both vi modes
bindkey -M viins '^L' clear-screen
bindkey -M vicmd '^L' clear-screen

# Use Tab for completion in command mode
bindkey -M vicmd '^I' vi-insert-bol

# Fix Shift-Tab in some terminals
bindkey -M viins -s '^[[Z' '\t'

# Menuselect keybindings
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
bindkey -M menuselect '^xu' undo
