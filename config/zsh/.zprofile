export SHELL_SESSIONS_DISABLE=1

# Language
export LANG="en_GB.UTF-8"
export LC_ALL=${LANG}

# Editors
export EDITOR="nvim"
export VISUAL=$EDITOR

if [ -z $HOMEBREW_PREFIX ]; then
    if [[ $(uname -m)="arm64" ]]; then
        HOMEBREW_PREFIX="/opt/homebrew"
    else
        HOMEBREW_PREFIX="/usr/local"
    fi
fi

MANPATH=
export MANPATH
[ -x /usr/libexec/path_helper ] && eval "$(/usr/libexec/path_helper -s)"
[ -x $HOMEBREW_PREFIX/bin/brew ] && eval "$($HOMEBREW_PREFIX/bin/brew shellenv)"
source $ZDOTDIR/lib/fpath.zsh
source $ZDOTDIR/lib/path.zsh

