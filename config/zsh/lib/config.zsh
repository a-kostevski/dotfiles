# ---Directory traversal ---
setopt auto_cd              # Go to folder path without using cd.
setopt auto_pushd           # Push the old directory onto the stack on cd.
setopt cdable_vars          # Change to a directory specified by a variable.
setopt pushd_ignore_dups    # Do not store duplicates in the stack.
setopt pushd_silent         # Do not print the directory stack after pushd or popd.

# --- Completions ---
setopt always_last_prompt   # Always put the prompt on the last line.
setopt always_to_end        # Move the cursor to the end of the line when accepting a completion.
setopt auto_list            # Automatically list choices on ambiguous completion.
setopt auto_menu            # Automatically use menu completion.
setopt auto_param_slash     # When completing a directory name, add a slash.
setopt auto_remove_slash    # Intelligently remove the trailing slash from a completed directory name.
setopt complete_aliases     # Complete aliases when the _expand_alias completer is used.
setopt complete_in_word     # Complete from both ends of a word.
setopt no_case_glob         # Perform case-insensitive globbing.
setopt no_flow_control      # Disable flow control.
setopt no_list_beep         # Beep when listing completions.
setopt no_list_rows_first   # Lay out matches in completion lists vertically.
setopt no_list_packed       # Do not remove empty lines from the list of matches.
setopt list_types           # List all types when listing completions.
unsetopt menu_complete      # Do not autoselect the first completion entry.
setopt path_dirs            # Perform path search even for command names with slashes.

# --- Expansion and globbing ---
setopt extended_glob        # Use extended globbing syntax. # Change directory to a path stored in a variable.
setopt no_case_glob         # Perform case-insensitive globbing.
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
