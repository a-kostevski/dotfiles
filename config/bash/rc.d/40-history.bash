# History configuration. Mirrors zsh/rc.d/40-history.zsh.

shopt -s histappend              # Append history to the history file.
shopt -s cmdhist                 # Save multi-line commands as one entry.
shopt -s histverify              # Do not execute immediately upon history expansion.

# bash does not create HISTFILE's parent directory
[[ -d "${XDG_STATE_HOME:-$HOME/.local/state}/bash" ]] || command mkdir -p -m 0700 "${XDG_STATE_HOME:-$HOME/.local/state}/bash"
export HISTFILE=$XDG_STATE_HOME/bash/history
export HISTSIZE=110000
export HISTFILESIZE=100000
export HISTTIMEFORMAT='%F %T '   # Record a timestamp for each command.
# ignorespace: do not record an event starting with a space.
# erasedups:   delete an old recorded event if a new event is a duplicate.
export HISTCONTROL=ignorespace:ignoredups:erasedups
export HISTIGNORE="ll:ls:cd:cd -:pwd:exit:date"

# Approximate zsh's share_history: flush each command to the file as it runs
# (new shells read it on startup; running shells keep their own view).
PROMPT_COMMAND="${PROMPT_COMMAND:+$PROMPT_COMMAND; }history -a"
