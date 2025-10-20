## Lazy loading helper for commands
_lazy_load_cmd() {
  local cmd="$1"
  local init_cmd="$2"

  eval "$cmd() {
    unfunction $cmd
    $init_cmd
    $cmd \"\$@\"
  }"
}

## fzf - load immediately as it's frequently used
if command_exists fzf; then
  # Try --zsh flag first (newer versions), fallback to shell-specific completion
  if fzf --zsh &>/dev/null; then
    source <(fzf --zsh)
  elif [[ -f ~/.fzf.zsh ]]; then
    source ~/.fzf.zsh
  fi
fi

## thefuck - lazy load as it's not needed immediately
if command_exists thefuck; then
  _lazy_load_cmd fuck 'eval "$(thefuck --alias)"'
fi

if test -n "$KITTY_INSTALLATION_DIR"; then
  export KITTY_SHELL_INTEGRATION="enabled"
  autoload -Uz -- "$KITTY_INSTALLATION_DIR"/shell-integration/zsh/kitty-integration
  kitty-integration
  unfunction kitty-integration
fi

## 1password - load immediately as it's security-critical
if command_exists op; then
  eval "$(op completion zsh)"
  compdef _op op
  export OP_BIOMETRIC_UNLOCK_ENABLED=1

  # Set SSH_AUTH_SOCK for 1Password SSH agent (macOS only)
  if is_macos; then
    local op_sock="$HOME/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"
    if [[ -S "$op_sock" ]]; then
      export SSH_AUTH_SOCK="$op_sock"
    fi
  fi
fi

## pyenv
# if command -v pyenv >/dev/null 2>&1; then
#   export PYENV_ROOT=$XDG_DATA_HOME/pyenv
#   eval "$(pyenv init -)"
#   [[ -z "${PYENV_VIRTUALENV_INIT}" ]] && eval "$(pyenv virtualenv-init -)"
# fi

## uv and uvx completions - lazy load
if command_exists uv; then
  _lazy_load_cmd uv 'eval "$(uv generate-shell-completion zsh)"'
fi

if command_exists uvx; then
  _lazy_load_cmd uvx 'eval "$(uvx --generate-shell-completion zsh)"'
fi

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
