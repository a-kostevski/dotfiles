export DEVDIR="$HOME/dev"
export REPOS="$DEVDIR/repos"
export GHDIR="$REPOS/github.com/a-kostevski"

# The CLI is linked from this repository into ~/.local/bin. Resolve that
# symlink so navigation and edit aliases work regardless of clone location.
dotfiles_bin="$(command -v dotfiles 2>/dev/null)"
if [[ -n "$dotfiles_bin" ]]; then
    export DOTDIR="${dotfiles_bin:A:h:h}"
else
    export DOTDIR="${DOTDIR:-$HOME/.dotfiles}"
fi
unset dotfiles_bin

export EXO="$HOME/exo"
export LIFE="$HOME/life"
export ZETDIR="$LIFE/0-inbox"

export EXO_DATA_HOME="$EXO"
export EXO_EDITOR="nvim"

# Go configuration lives in zshenv (GOPATH is needed by profile.d/10-path.zsh);
# GOROOT and PATH modifications are in profile.d/10-path.zsh

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

# Homebrew-specific compiler flags, only for kegs that are actually present
# (bzip2 dropped: it was never declared in packages.conf)
if [[ -n "$HOMEBREW_PREFIX" ]]; then
    _ldflags=""
    _cppflags=""
    for _keg in zlib readline; do
        if [[ -d "$HOMEBREW_PREFIX/opt/$_keg" ]]; then
            _ldflags+="-L$HOMEBREW_PREFIX/opt/$_keg/lib "
            _cppflags+="-I$HOMEBREW_PREFIX/opt/$_keg/include "
        fi
    done
    if [[ -n "$_ldflags" ]]; then
        export LDFLAGS="${_ldflags% }"
        export CPPFLAGS="${_cppflags% }"
    fi
    unset _ldflags _cppflags _keg
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
