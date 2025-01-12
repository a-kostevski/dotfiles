append_fpath() {
   local dir=$1
   if [[ -d $dir && ! " ${fpath[*]} " =~ " ${dir} " ]]; then
      fpath+=("$dir")
   fi
}

append_fpath "$HOMEBREW_PREFIX/share/zsh/site-functions"
append_fpath "$HOMEBREW_PREFIX/share/zsh-completions"
append_fpath "$ZDOTDIR/completions"
append_fpath "$ZDOTDIR/functions"

typeset -U fpath
