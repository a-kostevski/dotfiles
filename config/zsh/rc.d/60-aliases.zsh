# --- Navigation ---
alias ..="cd .."
alias ...="cd ../.."
alias ....="cd ../../.."
alias .....="cd ../../../.."

alias dev="cd ~/dev"
alias desk="cd ~/Desktop"
alias dot="cd $DOTDIR"
alias proj="cd ~/dev/projects"
alias life="cd ~/life"
alias inbox="cd ~/life/0-inbox/"
alias zets="cd ~/life/00-zettelkasten/"
alias conf="cd $XDG_CONFIG_HOME"
alias config="cd $XDG_CONFIG_HOME"
alias repos="cd ~/dev/repos"
alias ghrepos="cd ~/dev/repos/github.com/a-kostevski"
alias gorepos="cd $GOPATH"
alias clconfig="cd ~/Library/Application Support/Claude/"
alias c="clear"
alias clr="clear"

# --- Network ---
if is_macos; then
    alias getmac="ifconfig en0 | grep 'ether' | awk '{print \$2}'"
    alias localip4="ipconfig getifaddr en0"
    alias localip6="ifconfig en0 | grep inet6 | awk '{print \$2}'"
    alias routerip="ipconfig getoption en0 router"
else
    # Linux equivalents - note: interface name may vary
    alias getmac="ip link show | grep 'link/ether' | head -1 | awk '{print \$2}'"
    alias localip4="hostname -I | awk '{print \$1}'"
    alias localip6="ip -6 addr show scope global | grep inet6 | head -1 | awk '{print \$2}' | cut -d'/' -f1"
    alias routerip="ip route | grep default | awk '{print \$3}'"
fi

alias geoip="curl ipinfo.io/"
alias localip="localip4"
alias publicip4="curl http://ipinfo.io/ip"
alias publicip="publicip4"
alias openports="lsof -i -P -n | grep LISTEN"

alias urlencode="python -c 'import sys, urllib.parse as parse; print(parse.quote_plus(sys.argv[1]));'"
alias urldecode="python -c 'import sys, urllib.parse as parse; print(parse.unquote(sys.argv[1]));'"

# --- Config editing ---
alias dotconfig="cd $DOTDIR && $EDITOR ."
alias zshconfig="cd $DOTDIR/config/zsh  && $EDITOR ."
alias nvimconfig="cd $DOTDIR/config/nvim && $EDITOR ."

# --- Macos bins ---
if is_macos; then
    alias plistbuddy="/usr/libexec/PlistBuddy"
    alias lsregister="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
fi

# --- Command defaults ---
alias diff="colordiff"
alias grep='grep --color=auto' 
alias cat="bat"

alias map="xargs -n1"
alias vi="nvim"
alias vim="nvim"
alias zotify="zotify --config-location \"${XDG_CONFIG_HOME:-$HOME}/zotify/zconfig.json\""
alias npm="pnpm"
alias npx="pnpm"

 # --- ls ---
alias ls="eza --git --icons --group-directories-first"
alias la="eza -a --git --icons --group-directories-first"
alias ll="eza -ahlF --git --icons --group-directories-first"
alias lt="eza --tree --level=2 --group-directories-first" 

# --- Docker ---
# Load Docker utility functions
source "$ZDOTDIR/lib/docker.zsh"

# Docker aliases
alias dc=dc-fn
alias dcu="docker compose up -d"
alias dcd="docker compose down"
alias dcl=dcl-fn
alias dcre="docker compose down && docker compose up -d && docker compose logs -f"
alias dcr=dcr-fn
alias dex=dex-fn
alias di=di-fn
alias dim="docker images"
alias dip=dip-fn
alias dl=dl-fn
alias dnames=dnames-fn
alias dps="docker ps"
alias dpsa="docker ps -a"
alias drmc=drmc-fn
alias drmid=drmid-fn
alias drun=drun-fn
alias dsp="docker system prune --all"
alias dsr=dsr-fn

for p in path fpath manpath infopath; do
    alias $p='echo "${'${(U)p}'}" | tr ":" "\n"'
done

# --- Utils ---
# Cross-platform clipboard copy
if is_macos; then
    alias cpwd='pwd | tr -d "\n" | pbcopy'
    alias clip='pbcopy'
    alias clippaste='pbpaste'
    alias newpasswd="LC_ALL=C tr -dc \"[:rune:]\" < /dev/urandom | head -c 25 | pbcopy && echo \"Password copied to clipboard\""
elif command_exists xclip; then
    alias cpwd='pwd | tr -d "\n" | xclip -selection clipboard'
    alias clip='xclip -selection clipboard'
    alias clippaste='xclip -selection clipboard -o'
    alias newpasswd="LC_ALL=C tr -dc \"[:rune:]\" < /dev/urandom | head -c 25 | xclip -selection clipboard && echo \"Password copied to clipboard\""
elif command_exists wl-copy; then
    alias cpwd='pwd | tr -d "\n" | wl-copy'
    alias clip='wl-copy'
    alias clippaste='wl-paste'
    alias newpasswd="LC_ALL=C tr -dc \"[:rune:]\" < /dev/urandom | head -c 25 | wl-copy && echo \"Password copied to clipboard\""
fi

# Cross-platform open command
if is_macos; then
    # open is native on macOS
    :
elif command_exists xdg-open; then
    alias open='xdg-open'
fi

# macOS-specific utilities
if is_macos; then
    alias finder='cd $(osascript -e "tell application '\''Finder'\'' to POSIX path of (target of window 1 as alias)")'
    alias hidedesktop="defaults write com.apple.finder CreateDesktop -bool false && killall Finder"
    alias showdesktop="defaults write com.apple.finder CreateDesktop -bool true && killall Finder"
    alias macos_config="source $XDG_CONFIG_HOME/macos/defaults && source $XDG_CONFIG_HOME/macos/harden"
fi

# Homebrew-specific (available on both macOS and Linux if installed)
if command_exists brew; then
    alias brewgraph="brew graph --installed --highlight-leaves | fdp -T png -o $TMPDIR/brewgraph.png && open $TMPDIR/brewgraph.png"
fi

# PDF merge (requires ghostscript)
if command_exists gs; then
    alias mergepdf="gs -q -dNOPAUSE -dBATCH -sDEVICE=pdfwrite -sOutputFile=_merged.pdf"
fi

alias reload='[[ $SHLVL -eq 1 ]] && exec $SHELL || echo "Warning: Not reloading in subshell (level $SHLVL)"'

# --- Profiling ---
alias zshtimeprofile="time ZSH_PROFILING=true zsh -i -c exit;"
alias zshtime='for i in {1..10}; do time zsh -i -c exit; done'
