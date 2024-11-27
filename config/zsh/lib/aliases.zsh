# --- Navigation ---
alias ..="cd .."
alias ...="cd ../.."
alias ....="cd ../../.."
alias .....="cd ../../../.."

alias dev="cd ~/dev"
alias desk="cd ~/Desktop"
alias proj="cd ~/dev/projects"
alias conf="cd $XDG_CONFIG_HOME"

alias clr="clear;echo 'Currently logged in on $(tty), as $(whoami) in directory $(pwd).'"

# --- Network ---
alias getmac="ifconfig en0 | grep 'ether' | awk '{print \$2}'"
alias geoip="curl ipinfo.io/"
alias localip4="ipconfig getifaddr en0"
alias localip6="ifconfig en0 | grep inet6 | awk '{print \$2}'"
alias localip="localip4"
alias publicip4="curl http://ipinfo.io/ip"
alias publicip="publicip4"
alias routerip="ipconfig getoption en0 router"


alias urlencode="python -c 'import sys, urllib.parse as parse; print(parse.quote_plus(sys.argv[1]));'"
alias urldecode="python -c 'import sys, urllib.parse as parse; print(parse.unquote(sys.argv[1]));'"

# --- Config editing ---
alias dotconfig="cd $XDG_CONFIG_HOME && $EDITOR ."
alias zshconfig="cd $ZDOTDIR && $EDITOR ."
alias nvimconfig="cd $XDG_CONFIG_HOME/nvim && $EDITOR ."

# --- Macos bins ---
alias plistbuddy="/usr/libexec/PlistBuddy"
alias lsregister="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"

# --- Command defaults ---
alias diff="colordiff"
alias grep='grep --color=auto' 
alias ls="gls --color=auto -hA --group-directories-first -F"
alias ll="gls --color=auto -hAl --group-directories-first -F"
alias map="xargs -n1"
alias vim="nvim"
alias zotify="zotify --config-location \"${XDG_CONFIG_HOME:-$HOME}/zotify/zconfig.json\""

for p in path fpath manpath infopath; do
    alias $p='echo "${'${(U)p}'}" | tr ":" "\n"'
done

# --- Utils ---
alias finder='cd $(osascript -e "tell application 'Finder' to POSIX path of (target of window 1 as alias)")'
alias mergepdf="gs -q -dNOPAUSE -dBATCH -sDEVICE=pdfwrite -sOutputFile=_merged.pdf"

alias getpassword="LC_ALL=C tr -dc \"[:rune:]\" < /dev/urandom | head -c 25 | pbcopy && echo \"Password copied to clipboard\""

alias reload='[[ $SHLVL -eq 1 ]] && exec $SHELL || echo "Warning: Not reloading in subshell (level $SHLVL)"'

alias hidedesktop="defaults write com.apple.finder CreateDesktop -bool false && killall Finder"
alias showdesktop="defaults write com.apple.finder CreateDesktop -bool true && killall Finder"

alias brewgraph="brew graph --installed --highlight-leaves | fdp -T png -o $TMPDIR/brewgraph.png && open $TMPDIR/brewgraph.png"
alias macos_config="source $XDG_CONFIG_HOME/macos/defaults && source $XDG_CONFIG_HOME/macos/harden"

# --- Profiling ---
alias zshtimeprofile="time ZSH_PROFILING=true zsh -i -c exit;"
alias zshtime='for i in {1..10}; do time zsh -i -c exit; done'
