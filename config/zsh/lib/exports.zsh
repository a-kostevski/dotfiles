export ARCHFLAGS="-arch $(/usr/bin/arch)"

export DEVDIR="$HOME/dev"
export REPOS="$DEVDIR/repos"
export GHDIR="$REPOS/github.com/a-kostevski"
export DOTDIR="$GHDIR/dotfiles"
export LIFE="$HOME/life"
export ZETDIR="$LIFE/0-inbox"

export EXO_DATA_HOME="~/life"
export EXO_EDITOR="nvim"

export GOROOT="/opt/homebrew/opt/go/libexec"
export GOPATH="$XDG_DATA_HOME/go"
export GOMODCACHE="$XDG_CACHE_HOME/go/mod"
export GOCACHE="$XDG_CACHE_HOME/go/build"
export GOENV="$XDG_CONFIG_HOME/go/env"
path+=($GOPATH/bin $GOROOT/bin)

export LESS_TERMCAP_mb=$'\e[6m'       # begin blinking
export LESS_TERMCAP_md=$'\e[34m'      # begin bold
export LESS_TERMCAP_us=$'\e[4;32m'    # begin underline
export LESS_TERMCAP_so=$'\e[1;33;41m' # begin standout-mode - info box
export LESS_TERMCAP_me=$'\e[m'        # end mode
export LESS_TERMCAP_ue=$'\e[m'        # end underline
export LESS_TERMCAP_se=$'\e[m'        # end standout-mode
export LESS='-iRFXMx4'
export PAGER='less'
export MANPAGER='less'

export CLICOLOR=1
export TERM=${TERM:-xterm-256color}

export HOMEBREW_PREFIX='/opt/homebrew'

export LDFLAGS="-L${HOMEBREW_PREFIX}/opt/zlib/lib -L${HOMEBREW_PREFIX}/opt/bzip2/lib -L${HOMEBREW_PREFIX}/opt/readline/lib"
export CPPFLAGS="-I${HOMEBREW_PREFIX}/opt/zlib/include -I${HOMEBREW_PREFIX}/opt/bzip3/include -I${HOMEBREW_PREFIX}/opt/readline/include"

# Python
export PYTHONIOENCODING='UTF-8'
export PYTHON_CONFIGURE_OPTS='--enable-optimizations --with-lto'
export PYTHON_CFLAGS='-march=native -mtune=native'

# Avoid issues with `gpg` as installed via Homebrew.
export GPG_TTY=$(tty)

# Homebrew settings that require parameter expansion.
export HOMEBREW_LOGS="$XDG_STATE_HOME/Homebrew/Logs"

export REPORTTIME=10
