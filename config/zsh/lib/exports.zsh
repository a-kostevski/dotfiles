export ARCHFLAGS="-arch $(/usr/bin/arch)"

export LESS_TERMCAP_mb=$'\e[6m'          # begin blinking
export LESS_TERMCAP_md=$'\e[34m'         # begin bold
export LESS_TERMCAP_us=$'\e[4;32m'       # begin underline
export LESS_TERMCAP_so=$'\e[1;33;41m'    # begin standout-mode - info box
export LESS_TERMCAP_me=$'\e[m'           # end mode
export LESS_TERMCAP_ue=$'\e[m'           # end underline
export LESS_TERMCAP_se=$'\e[m'           # end standout-mode
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
export ITERM2_SQUELCH_MARK=0

# Homebrew settings that require parameter expansion. 
export HOMEBREW_LOGS="$XDG_STATE_HOME/Homebrew/Logs"

export NULLCMD='cat'
export REPORTTIME=10


