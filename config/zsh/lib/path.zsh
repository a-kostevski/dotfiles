append_path() {
    local dir=$1
    if [[ -d $dir && ! " ${path[*]} " =~ " ${dir} " ]]; then
        path=("$dir" "$path[@]")
    fi
}

append_path /bin
append_path /sbin
append_path /usr/bin
append_path /usr/sbin
append_path /usr/local/sbin
append_path /usr/local/bin
append_path "$HOME/.local/bin"
append_path "$HOME/.local/share/pnpm"
append_path "$HOMEBREW_PREFIX/opt/postgresql@16/bin"
append_path "$HOMEBREW_PREFIX/opt/ruby/bin"
append_path "$HOMEBREW_PREFIX/opt/curl/bin"
append_path "$HOMEBREW_PREFIX/opt/openjdk/bin"
append_path "$HOMEBREW_PREFIX/opt/rustup/bin"

typeset -U path
