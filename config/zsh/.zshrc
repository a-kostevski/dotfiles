[[ -n $ZSH_PROFILING ]] && zmodload zsh/zprof

ZSH_FUNCTIONS=$ZDOTDIR/functions
if [[ -d "$ZSH_FUNCTIONS" ]]; then
   for func in $ZSH_FUNCTIONS/*; do
      autoload -Uz ${func:t}
   done
fi
unset ZSH_FUNCTIONS

# Load interactive shell configurations
for config_file ($ZDOTDIR/rc.d/*.zsh(N)); do
    source $config_file
done

# Load theme
[ -f $ZDOTDIR/theme/dir_colors ] && eval $(gdircolors -b $ZDOTDIR/theme/dir_colors)

if [[ -n $ZSH_PROFILING ]]; then
   zprof
   unset ZSH_PROFILING
fi
