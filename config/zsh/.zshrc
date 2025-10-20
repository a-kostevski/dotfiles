[[ -n $ZSH_PROFILING ]] && zmodload zsh/zprof

ZSH_FUNCTIONS="$ZDOTDIR/functions"
if [[ -d "$ZSH_FUNCTIONS" ]]; then
   for func in "$ZSH_FUNCTIONS"/*; do
      autoload -Uz "${func:t}"
   done
fi
unset ZSH_FUNCTIONS

# Load interactive shell configurations
for config_file in "$ZDOTDIR"/rc.d/*.zsh(N); do
    source "$config_file"
done

# Load theme
if [[ -f $ZDOTDIR/theme/dir_colors ]]; then
    local dircolors_cmd=$(get_dircolors_command)
    [[ -n "$dircolors_cmd" ]] && eval $($dircolors_cmd -b $ZDOTDIR/theme/dir_colors)
fi

if [[ -n $ZSH_PROFILING ]]; then
   zprof
   unset ZSH_PROFILING
fi
