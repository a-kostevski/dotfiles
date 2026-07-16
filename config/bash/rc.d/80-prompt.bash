# Prompt. Mirrors zsh/rc.d/80-prompt.zsh: cyan [user@host], white cwd, git
# info as red λ:branch with blue * (unstaged) / green + (staged), blue > on
# its own line. bash has no RPROMPT, so the git segment follows the cwd.

# \001/\002 mark non-printing sequences for readline inside expanded variables
# (the PS1-literal \[ \] forms don't survive variable expansion).
__prompt_vcs() {
    _prompt_vcs=""
    local branch flags=""
    branch=$(git symbolic-ref --quiet --short HEAD 2>/dev/null) \
        || branch=$(git rev-parse --short HEAD 2>/dev/null) \
        || return 0
    git diff --no-ext-diff --quiet 2>/dev/null || flags+=$' \001\e[34m\002*\001\e[0m\002'
    git diff --no-ext-diff --cached --quiet 2>/dev/null || flags+=$' \001\e[32m\002+\001\e[0m\002'
    _prompt_vcs=$' \001\e[31m\002λ\001\e[0m\002:'"${branch}${flags}"
}

PROMPT_COMMAND="${PROMPT_COMMAND:+$PROMPT_COMMAND; }__prompt_vcs"

PS1='\[\e[36m\][\u@\h]\[\e[0m\] \[\e[37m\]\w\[\e[0m\]${_prompt_vcs}\n \[\e[1;34m\]>\[\e[0m\] '
