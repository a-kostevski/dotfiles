append_path() {
   local dir="$1"
   if [[ -d "$dir" && ! " ${path[*]} " =~ " $dir " ]]; then
      path+=("$dir")
   fi
}

prepend_path() {
   local dir="$1"
   if [[ -d "$dir" && ! " ${path[*]} " =~ " $dir " ]]; then
      path=("$dir" "${path[@]}")
   fi
}

prepend_path "$HOME/.local/bin"
prepend_path "$HOME/.local/share/pnpm"
prepend_path "$HOME/.local/share/npm/bin"

# Ubuntu-specific paths
if [[ "$(uname -s)" == "Linux" ]]; then
    prepend_path "/opt/nvim/bin"
fi

# Go paths (GOROOT and GOPATH bins)
# GOPATH is set in zshenv, GOROOT may be set via Homebrew or go binary
if [[ -n "$HOMEBREW_PREFIX" ]] && [[ -d "$HOMEBREW_PREFIX/opt/go/libexec" ]]; then
    export GOROOT="$HOMEBREW_PREFIX/opt/go/libexec"
    prepend_path "$GOROOT/bin"
elif command -v go &>/dev/null; then
    export GOROOT="$(go env GOROOT 2>/dev/null)"
fi

# Add GOPATH bin to path if GOPATH is set
if [[ -n "$GOPATH" ]]; then
    prepend_path "$GOPATH/bin"
fi

# Homebrew-specific paths (only if Homebrew is installed)
if [[ -n "$HOMEBREW_PREFIX" ]]; then
    prepend_path "$HOMEBREW_PREFIX/opt/ruby/bin"
    prepend_path "$HOMEBREW_PREFIX/opt/postgresql@16/bin"
fi

append_path /usr/local/bin
append_path /usr/bin
append_path /bin
append_path /usr/sbin
append_path /sbin
