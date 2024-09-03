append_fpath() {
    local dir=$1
    if [[ ! " ${fpath[*]} " =~ " ${dir} " ]]; then
        fpath=($dir $fpath)
    fi
}
append_fpath $HOMEBREW_PREFIX/share/zsh/site-functions
append_fpath $HOMEBREW_PREFIX/share/zsh-completions
append_fpath $ZDOTDIR/functions
typeset -U fpath
