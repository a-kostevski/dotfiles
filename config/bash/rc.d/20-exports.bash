# Interactive-session exports. Mirrors zsh/rc.d/20-exports.zsh.

export DEVDIR="$HOME/dev"
export REPOS="$DEVDIR/repos"
export GHDIR="$REPOS/github.com/a-kostevski"

# The CLI is linked from this repository into ~/.local/bin. Resolve that
# symlink so navigation and edit aliases work regardless of clone location.
_resolve_link() {
    local p="$1" t
    while [[ -L "$p" ]]; do
        t=$(readlink "$p")
        case "$t" in
            /*) p="$t" ;;
            *) p="$(dirname "$p")/$t" ;;
        esac
    done
    printf '%s' "$p"
}

dotfiles_bin=$(command -v dotfiles 2>/dev/null)
if [[ -n "$dotfiles_bin" ]]; then
    dotfiles_bin=$(_resolve_link "$dotfiles_bin")
    export DOTDIR="$(cd "$(dirname "$dotfiles_bin")/.." && pwd -P)"
else
    export DOTDIR="${DOTDIR:-$HOME/.dotfiles}"
fi
unset dotfiles_bin
unset -f _resolve_link

export EXO="$HOME/exo"
export LIFE="$HOME/life"
export ZETDIR="$LIFE/0-inbox"

export EXO_DATA_HOME="$EXO"
export EXO_EDITOR="nvim"

# Go configuration lives in env.bash (GOPATH is needed by profile.d/10-path.bash);
# GOROOT and PATH modifications are in profile.d/10-path.bash

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
if [[ -n "${HOMEBREW_PREFIX:-}" ]]; then
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
