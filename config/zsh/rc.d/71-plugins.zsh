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
  # Capture once, then source only when generation succeeded.
  _fzf_init="$(fzf --zsh 2>/dev/null)"
  if [[ -n "$_fzf_init" ]]; then
    source <(print -r -- "$_fzf_init")
  elif [[ -f ~/.fzf.zsh ]]; then
    source ~/.fzf.zsh
  fi
  unset _fzf_init
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
  # Cache completion script for faster startup (mirrors brew_shellenv caching)
  local op_cache="$XDG_CACHE_HOME/zsh/op_completion"
  local op_bin="$(command -v op)"
  if [[ ! -f "$op_cache" ]] || [[ "$op_bin" -nt "$op_cache" ]]; then
    mkdir -p "${op_cache:h}"
    op completion zsh > "$op_cache"
  fi
  source "$op_cache"
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

## zsh-defer - loads synchronously; subsequent _plug_load calls defer
_plug_load "romkatv/zsh-defer"

## zsh-completions - clone only; 30-completions.zsh adds it to fpath before compinit
_plug_clone "zsh-users/zsh-completions"

## zsh-autosuggestions
export ZSH_AUTOSUGGEST_STRATEGY=(history completion)
export ZSH_AUTOSUGGEST_BUFFER_MAX_SIZE=20
_plug_load "zsh-users/zsh-autosuggestions"

## zsh-syntax-highlighting - must load after autosuggestions (it wraps
## existing ZLE widgets and misses ones defined later)
export ZSH_HIGHLIGHT_MAXLENGTH=200
export ZSH_HIGHLIGHT_HIGHLIGHTERS=(main brackets pattern cursor)
_plug_load "zsh-users/zsh-syntax-highlighting"
