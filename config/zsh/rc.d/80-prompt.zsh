autoload -Uz vcs_info add-zsh-hook

# Configure vcs_info
zstyle ':vcs_info:*' enable git
zstyle ':vcs_info:*' formats ' %F{red}λ%f:%b%u%c'
zstyle ':vcs_info:*' actionformats ' %F{red}λ%f:%b|%a%u%c'
zstyle ':vcs_info:*' unstagedstr ' %F{blue}%f'
zstyle ':vcs_info:*' stagedstr ' %F{green}+%f'

# Add vcs_info to precmd hooks instead of overwriting precmd
add-zsh-hook precmd vcs_info

PROMPT=$'%F{white}%~\n %B%F{blue}>%f%b '
RPROMPT='${vcs_info_msg_0_}'
