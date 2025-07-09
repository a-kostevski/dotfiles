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
alias getmac="ifconfig en0 | grep 'ether' | awk '{print \$2}'"
alias geoip="curl ipinfo.io/"
alias localip4="ipconfig getifaddr en0"
alias localip6="ifconfig en0 | grep inet6 | awk '{print \$2}'"
alias localip="localip4"
alias publicip4="curl http://ipinfo.io/ip"
alias publicip="publicip4"
alias routerip="ipconfig getoption en0 router"

alias openports="lsof -i -P -n | grep LISTEN"

alias urlencode="python -c 'import sys, urllib.parse as parse; print(parse.quote_plus(sys.argv[1]));'"
alias urldecode="python -c 'import sys, urllib.parse as parse; print(parse.unquote(sys.argv[1]));'"

# --- Config editing ---
alias dotconfig="cd $DOTDIR && $EDITOR ."
alias zshconfig="cd $DOTDIR/config/zsh  && $EDITOR ."
alias nvimconfig="cd $DOTDIR/config/nvim && $EDITOR ."

# --- Macos bins ---
alias plistbuddy="/usr/libexec/PlistBuddy"
alias lsregister="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"

# --- Command defaults ---
alias diff="colordiff"
alias grep='grep --color=auto' 
alias cat="bat"

alias map="xargs -n1"
alias vi="nvim"
alias vim="nvim"
alias zotify="zotify --config-location \"${XDG_CONFIG_HOME:-$HOME}/zotify/zconfig.json\""

 # --- ls ---
alias ls="eza --git --icons --group-directories-first"
alias la="eza -a --git --icons --group-directories-first"
alias ll="eza -ahlF --git --icons --group-directories-first"
alias lt="eza --tree --level=2 --group-directories-first" 


for p in path fpath manpath infopath; do
    alias $p='echo "${'${(U)p}'}" | tr ":" "\n"'
done

# --- Utils ---
alias cpwd='pwd | tr -d "\n" | pbcopy'
alias finder='cd $(osascript -e "tell application 'Finder' to POSIX path of (target of window 1 as alias)")'
alias mergepdf="gs -q -dNOPAUSE -dBATCH -sDEVICE=pdfwrite -sOutputFile=_merged.pdf"

alias newpasswd="LC_ALL=C tr -dc \"[:rune:]\" < /dev/urandom | head -c 25 | pbcopy && echo \"Password copied to clipboard\""

alias reload='[[ $SHLVL -eq 1 ]] && exec $SHELL || echo "Warning: Not reloading in subshell (level $SHLVL)"'

alias hidedesktop="defaults write com.apple.finder CreateDesktop -bool false && killall Finder"
alias showdesktop="defaults write com.apple.finder CreateDesktop -bool true && killall Finder"

alias brewgraph="brew graph --installed --highlight-leaves | fdp -T png -o $TMPDIR/brewgraph.png && open $TMPDIR/brewgraph.png"
alias macos_config="source $XDG_CONFIG_HOME/macos/defaults && source $XDG_CONFIG_HOME/macos/harden"

# --- Profiling ---
alias zshtimeprofile="time ZSH_PROFILING=true zsh -i -c exit;"
alias zshtime='for i in {1..10}; do time zsh -i -c exit; done'
