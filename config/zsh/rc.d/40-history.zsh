setopt append_history            # Append history to the history file.
setopt hist_ignore_dups          # Do not record an event that was just recorded again.
setopt hist_ignore_all_dups      # Delete an old recorded event if a new event is a duplicate.
setopt hist_find_no_dups         # Do not display a previously found event.
setopt hist_ignore_space         # Do not record an event starting with a space.
setopt hist_save_no_dups         # Do not write a duplicate event to the history file.
setopt hist_verify               # Do not execute immediately upon history expansion.
setopt share_history             # Share history between all sessions.

export HISTFILE=$XDG_STATE_HOME/zsh/zhistory
export HISTSIZE=1000000000
export SAVEHIST=1000000000
export HIST_STAMPS="yyyy-mm-dd"
export HISTCONTROL='ignoreboth'
export HISTIGNORE="ll:ls:cd:cd -:pwd:exit:date"