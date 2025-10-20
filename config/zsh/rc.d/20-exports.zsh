export DEVDIR="$HOME/dev"
export REPOS="$DEVDIR/repos"
export GHDIR="$REPOS/github.com/a-kostevski"
export DOTDIR="$GHDIR/dotfiles"
export EXO="$HOME/exo"
export ZETDIR="$LIFE/0-inbox"

export EXO_DATA_HOME="~/exo"
export EXO_EDITOR="nvim"

# Go configuration
# Note: GOROOT and PATH modifications are in profile.d/10-path.zsh
export GOPATH="$XDG_DATA_HOME/go"
export GOMODCACHE="$XDG_CACHE_HOME/go/mod"
export GOCACHE="$XDG_CACHE_HOME/go/build"
export GOENV="$XDG_CONFIG_HOME/go/env"

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

# Homebrew-specific compiler flags (only set if Homebrew is installed)
if [[ -n "$HOMEBREW_PREFIX" ]]; then
    export LDFLAGS="-L${HOMEBREW_PREFIX}/opt/zlib/lib -L${HOMEBREW_PREFIX}/opt/bzip2/lib -L${HOMEBREW_PREFIX}/opt/readline/lib"
    export CPPFLAGS="-I${HOMEBREW_PREFIX}/opt/zlib/include -I${HOMEBREW_PREFIX}/opt/bzip3/include -I${HOMEBREW_PREFIX}/opt/readline/include"
fi

# Python
export PYTHONIOENCODING='UTF-8'
export PYTHON_CONFIGURE_OPTS='--enable-optimizations --with-lto'
export PYTHON_CFLAGS='-march=native -mtune=native'

# Avoid issues with `gpg` as installed via Homebrew.
export GPG_TTY=$(tty)

# Homebrew settings (only set if Homebrew is installed)
if command_exists brew; then
    export HOMEBREW_LOGS="$XDG_STATE_HOME/Homebrew/Logs"
fi

export REPORTTIME=10
