typeset -U fpath FPATH

append_fpath() {
   local dir="$1"
   [[ -d "$dir" ]] && fpath+=("$dir")
}

# Homebrew-specific completion paths (only if Homebrew is installed)
if [[ -n "$HOMEBREW_PREFIX" ]]; then
    append_fpath "$HOMEBREW_PREFIX/share/zsh/functions"
    append_fpath "$HOMEBREW_PREFIX/share/zsh/site-functions"
    append_fpath "$HOMEBREW_PREFIX/share/zsh-completions"
fi

append_fpath "$ZDOTDIR/completions"
append_fpath "$ZDOTDIR/functions"
