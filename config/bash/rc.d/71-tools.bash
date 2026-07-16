# Tool integrations. Mirrors zsh/rc.d/71-plugins.zsh.
#
# Deliberate omissions from the zsh file: the zsh-unplugged plugin section
# (zsh-defer, zsh-completions, zsh-autosuggestions, zsh-syntax-highlighting)
# has no bash counterpart — ble.sh is intentionally not adopted.

## Lazy loading helper for commands
_lazy_load_cmd() {
    local cmd="$1"
    local init_cmd="$2"

    eval "$cmd() {
        unset -f $cmd
        $init_cmd
        $cmd \"\$@\"
    }"
}

## fzf - load immediately as it's frequently used
if command_exists fzf; then
    # Cache the init script for faster startup (mirrors op_completion caching)
    _fzf_cache="${XDG_CACHE_HOME:-$HOME/.cache}/bash/fzf_init"
    _fzf_bin="$(command -v fzf)"
    if [[ ! -f "$_fzf_cache" ]] || [[ "$_fzf_bin" -nt "$_fzf_cache" ]]; then
        mkdir -p "$(dirname "$_fzf_cache")"
        fzf --bash > "$_fzf_cache" 2>/dev/null || : > "$_fzf_cache"
    fi
    if [[ -s "$_fzf_cache" ]]; then
        # shellcheck source=/dev/null
        source "$_fzf_cache"
    elif [[ -f ~/.fzf.bash ]]; then
        # shellcheck source=/dev/null
        source ~/.fzf.bash
    fi
    unset _fzf_cache _fzf_bin
fi

## thefuck - lazy load as it's not needed immediately
if command_exists thefuck; then
    _lazy_load_cmd fuck 'eval "$(thefuck --alias)"'
fi

## direnv - cannot lazy load; the PROMPT_COMMAND hook must be active before
## the first prompt in a directory with an .envrc
if command_exists direnv; then
    eval "$(direnv hook bash)"
fi

if [[ -n "${KITTY_INSTALLATION_DIR:-}" ]]; then
    export KITTY_SHELL_INTEGRATION="enabled"
    # shellcheck source=/dev/null
    source "$KITTY_INSTALLATION_DIR/shell-integration/bash/kitty.bash"
fi

## 1password - load immediately as it's security-critical
if command_exists op; then
    # Cache completion script for faster startup (mirrors brew_shellenv caching)
    _op_cache="${XDG_CACHE_HOME:-$HOME/.cache}/bash/op_completion"
    _op_bin="$(command -v op)"
    if [[ ! -f "$_op_cache" ]] || [[ "$_op_bin" -nt "$_op_cache" ]]; then
        mkdir -p "$(dirname "$_op_cache")"
        op completion bash > "$_op_cache"
    fi
    # shellcheck source=/dev/null
    source "$_op_cache"
    unset _op_cache _op_bin
    export OP_BIOMETRIC_UNLOCK_ENABLED=1

    # Set SSH_AUTH_SOCK for 1Password SSH agent (macOS only)
    if is_macos; then
        _op_sock="$HOME/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"
        if [[ -S "$_op_sock" ]]; then
            export SSH_AUTH_SOCK="$_op_sock"
        fi
        unset _op_sock
    fi
fi

## uv and uvx completions - lazy load
if command_exists uv; then
    _lazy_load_cmd uv 'eval "$(uv generate-shell-completion bash)"'
fi

if command_exists uvx; then
    _lazy_load_cmd uvx 'eval "$(uvx --generate-shell-completion bash)"'
fi
