export SHELL_SESSIONS_DISABLE=1

MANPATH=
export MANPATH
[ -x /usr/libexec/path_helper ] && eval "$(/usr/libexec/path_helper -s)"

# Next, set up Homebrew
if [ -z $HOMEBREW_PREFIX ]; then
   if [[ $(uname -m) == "arm64" ]]; then
      HOMEBREW_PREFIX="/opt/homebrew"
   else
      HOMEBREW_PREFIX="/usr/local"
   fi
fi

# Cache brew shellenv for faster startup
if [ -x $HOMEBREW_PREFIX/bin/brew ]; then
   local brew_cache="$XDG_CACHE_HOME/zsh/brew_shellenv"
   local brew_bin="$HOMEBREW_PREFIX/bin/brew"

   # Regenerate cache if brew is newer than cache or cache doesn't exist
   if [[ ! -f "$brew_cache" ]] || [[ "$brew_bin" -nt "$brew_cache" ]]; then
      mkdir -p "${brew_cache:h}"
      "$brew_bin" shellenv > "$brew_cache"
   fi

   source "$brew_cache"
fi

for config_file in $ZDOTDIR/profile.d/*.zsh(N); do
    source "$config_file"
done

typeset -U PATH path
typeset -U FPATH fpath

