## fzf
source <(fzf --zsh)

## The fuck?
eval "$(thefuck --alias)"

if test -n "$KITTY_INSTALLATION_DIR"; then
  export KITTY_SHELL_INTEGRATION="enabled"
  autoload -Uz -- "$KITTY_INSTALLATION_DIR"/shell-integration/zsh/kitty-integration
  kitty-integration
  unfunction kitty-integration
fi

## 1password
if command -v op >/dev/null 2>&1; then
  eval "$(op completion zsh)"
  compdef _op op
  export OP_BIOMETRIC_UNLOCK_ENABLED=1
  export SSH_AUTH_SOCK=~/Library/Group\ Containers/2BUA8C4S2C.com.1password/t/agent.sock
fi

## pyenv
# if command -v pyenv >/dev/null 2>&1; then
#   export PYENV_ROOT=$XDG_DATA_HOME/pyenv
#   eval "$(pyenv init -)"
#   [[ -z "${PYENV_VIRTUALENV_INIT}" ]] && eval "$(pyenv virtualenv-init -)"
# fi

eval "$(uv generate-shell-completion zsh)"
eval "$(uvx --generate-shell-completion zsh)"

##
_plug_load "zsh-users/zsh-completions"

## zsh-syntax-highlighting
_plug_load "zsh-users/zsh-syntax-highlighting"
export ZSH_HIGHLIGHT_MAXLENGTH=200

## zsh-autosuggestions
_plug_load "zsh-users/zsh-autosuggestions"
export ZSH_AUTOSUGGEST_STRATEGY=(history completion)
export ZSH_AUTOSUGGEST_BUFFER_MAX_SIZE=20
export ZSH_HIGHLIGHT_HIGHLIGHTERS=(main brackets pattern cursor)
