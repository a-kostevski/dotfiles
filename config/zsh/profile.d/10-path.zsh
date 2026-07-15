typeset -U path PATH

append_path() {
   local dir="$1"
   [[ -d "$dir" ]] && path+=("$dir")
}

prepend_path() {
   local dir="$1"
   [[ -d "$dir" ]] && path=("$dir" "${path[@]}")
}

prepend_path "$HOME/.local/bin"
prepend_path "$PNPM_HOME"
prepend_path "$XDG_DATA_HOME/npm/bin"

# Ubuntu-specific paths
if [[ "$OSTYPE" == linux* ]]; then
    prepend_path "/opt/nvim/bin"
fi

# Go paths (GOROOT and GOPATH bins)
# GOPATH is set in zshenv, GOROOT may be set via Homebrew
if [[ -n "$HOMEBREW_PREFIX" ]] && [[ -d "$HOMEBREW_PREFIX/opt/go/libexec" ]]; then
    export GOROOT="$HOMEBREW_PREFIX/opt/go/libexec"
    prepend_path "$GOROOT/bin"
fi

# Add GOPATH bin to path if GOPATH is set
if [[ -n "$GOPATH" ]]; then
    prepend_path "$GOPATH/bin"
fi

# Homebrew-specific paths (only if Homebrew is installed)
if [[ -n "$HOMEBREW_PREFIX" ]]; then
    prepend_path "$HOMEBREW_PREFIX/opt/ruby/bin"
fi

append_path /usr/local/bin
append_path /usr/bin
append_path /bin
append_path /usr/sbin
append_path /sbin
