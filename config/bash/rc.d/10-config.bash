# Shell options. Mirrors zsh/rc.d/10-config.zsh where bash has an equivalent.

# --- Directory traversal ---
shopt -s autocd 2>/dev/null      # Go to folder path without using cd (bash 4+).
shopt -s cdable_vars             # Change to a directory specified by a variable.
shopt -s cdspell                 # Correct minor spelling errors in cd arguments.
shopt -s dirspell 2>/dev/null    # Correct spelling during directory completion (bash 4+).

# --- Expansion and globbing ---
shopt -s extglob                 # Use extended globbing syntax.
shopt -s globstar 2>/dev/null    # ** matches recursively (bash 4+).
shopt -s nocaseglob              # Perform case-insensitive globbing.

# --- I/O ---
shopt -s checkwinsize            # Update LINES/COLUMNS after each command.
shopt -s no_empty_cmd_completion # Don't complete on an empty line.
shopt -s interactive_comments    # Allow comments even in interactive shells.
bind 'set bell-style none'       # Do not beep on errors.
