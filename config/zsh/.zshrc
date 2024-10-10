source /etc/zshrc

if [[ -n $ZSH_PROFILING ]]; then
    zmodload zsh/zprof
fi

ZSH_FUNCTIONS=$ZDOTDIR/functions
if [[ -d "$ZSH_FUNCTIONS" ]]; then
    for func in $ZSH_FUNCTIONS/*; do
        autoload -Uz ${func:t}
    done
fi
unset ZSH_FUNCTIONS

ZLIB=$ZDOTDIR/lib
ZTHEME=$ZDOTDIR/theme

source $ZLIB/config.zsh
source $ZLIB/history.zsh
source $ZLIB/exports.zsh
source $ZLIB/aliases.zsh
source $ZLIB/completions.zsh
source $ZLIB/keybindings.zsh
source $ZLIB/plugins.zsh
source $ZLIB/prompt.zsh
source $ZLIB/window.zsh

[ -f $ZTHEME/dir_colors ] && eval $(gdircolors -b $ZTHEME/dir_colors)
unset ZLIB

if [[ -n $ZSH_PROFILING ]]; then
    zprof
    unset ZSH_PROFILING
fi

