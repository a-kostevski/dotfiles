append_path() {
   local dir=$1
   if [[ -d $dir && ! " ${path[*]} " =~ " ${dir} " ]]; then
      path+=("$dir")
   fi
}

prepend_path() {
   local dir=$1
   if [[ -d $dir && ! " ${path[*]} " =~ " ${dir} " ]]; then
      path=("$dir" $path[@])
   fi
}

prepend_path "$HOME/.local/bin"
prepend_path "$HOME/.local/share/pnpm"
prepend_path "$HOMEBREW_PREFIX/opt/postgresql@16/bin"
prepend_path "/Users/antonkostevski/.local/share/npm/bin"
append_path /usr/local/bin
append_path /usr/bin
append_path /bin
append_path /usr/sbin
append_path /sbin
