## fzf
source <(fzf --zsh)

## 1password
eval "$(op completion zsh)"; compdef _op op
export OP_BIOMETRIC_UNLOCK_ENABLED=1
export SSH_AUTH_SOCK=~/Library/Group\ Containers/2BUA8C4S2C.com.1password/t/agent.sock

## pyenv
export PYENV_ROOT=$XDG_DATA_HOME/pyenv
eval "$(pyenv init -)"
eval "$(pyenv virtualenv-init -)"

## zsh-syntax-highlighting
source $HOMEBREW_PREFIX/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
export ZSH_HIGHLIGHT_MAXLENGTH=200

## zsh-autosuggestions
source $HOMEBREW_PREFIX/share/zsh-autosuggestions/zsh-autosuggestions.zsh
export ZSH_AUTOSUGGEST_STRATEGY=(history completion)
export ZSH_AUTOSUGGEST_BUFFER_MAX_SIZE=20
export ZSH_HIGHLIGHT_HIGHLIGHTERS=(main brackets pattern cursor)


