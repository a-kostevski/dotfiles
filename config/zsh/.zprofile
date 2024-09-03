export SHELL_SESSIONS_DISABLE=1

# Language
export LANG="en_GB.UTF-8"
export LANGUAGE=${LANG}
export LC_ADDRESS=${LANG}
export LC_ALL=${LANG}
export LC_COLLATE=${LANG}
export LC_CTYPE=${LANG}
export LC_IDENTIFICATION=${LANG}
export LC_MEASUREMENT=${LANG}
export LC_MESSAGES=${LANG}
export LC_MONETARY=${LANG}
export LC_NAME=${LANG}
export LC_PAPER=${LANG}
export LC_TELEPHONE=${LANG}
export LC_TIME=${LANG}

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
typeset +U path fpath manpath infopath

