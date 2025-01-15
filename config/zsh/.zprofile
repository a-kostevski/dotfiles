export SHELL_SESSIONS_DISABLE=1

MANPATH=
export MANPATH
[ -x /usr/libexec/path_helper ] && eval "$(/usr/libexec/path_helper -s)"

# Next, set up Homebrew
if [ -z $HOMEBREW_PREFIX ]; then
   if [[ $(uname -m)="arm64" ]]; then
      HOMEBREW_PREFIX="/opt/homebrew"
   else
      HOMEBREW_PREFIX="/usr/local"
   fi
fi

[ -x $HOMEBREW_PREFIX/bin/brew ] && eval "$($HOMEBREW_PREFIX/bin/brew shellenv)"

for config_file ($ZDOTDIR/profile.d/*.zsh(N)); do
    source $config_file
done

typeset -U PATH path
typeset -U FPATH fpath

