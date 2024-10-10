# ---Directory traversal ---
setopt auto_cd              # Go to folder path without using cd.
setopt auto_pushd           # Push the old directory onto the stack on cd.
setopt cdable_vars          # Change to a directory specified by a variable.
setopt pushd_ignore_dups    # Do not store duplicates in the stack.
setopt pushd_silent         # Do not print the directory stack after pushd or popd.
 

# --- Expansion and globbing ---
setopt extended_glob        # Use extended globbing syntax. # Change directory to a path stored in a variable.
setopt no_glob_dots         # Do not include . and .. in globbing.
unsetopt no_match           # Do not print an error message if no matches are found.
setopt numericglobsort      # Sort filenames numerically when it makes sense.

# --- I/O ---
setopt correct              # Spelling correction
setopt no_correct_all       # Don't correct all arguments in a line.
setopt ignore_eof           # Do not exit upon reading EOF (Ctrl^D).
setopt interactivecomments  # Allow comments even in interactive shells.
setopt no_dvorak            # Do not use Dvorak key bindings.
setopt aliases              # Enable alias expansion.
setopt no_beep              # Do not beep on errors.

# --- Prompts ---
setopt prompt_subst         # Enable prompt substitution.

# --- Scripts and functions ---
setopt local_options        # Set options locally in functions.
setopt local_traps          # Set traps locally in functions.
