append_path() {
    local dir=$1
    [[ -d $dir && ! $path[(r)$dir] ]] && path=($dir $path)
}
append_path /bin
append_path /sbin
append_path /usr/local/sbin
append_path /usr/local/bin
append_path /opt/homebrew/opt/postgresql@16/bin
append_path /opt/homebrew/opt/ruby/bin
append_path /opt/homebrew/opt/curl/bin
append_path /opt/homebrew/opt/openjdk/bin
append_path /Users/antonkostevski/.local/bin

