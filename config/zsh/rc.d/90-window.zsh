# https://github.com/holman/dotfiles/blob/master/zsh/window.zsh
function title() {
    local a
    # escape '%' chars in $1, make nonprintables visible
    a=${(V)1//\%/\%\%}
    # Truncate command, and join lines.
    a=$(print -Pn "%40>...>$a" | tr -d "\n")

    case $TERM in
    screen* | tmux*)
        print -Pn "\ek$a\e\\" # screen/tmux window title (in ^A")
        ;;
    xterm* | rxvt)
        print -Pn "\e]2;$2\a" # plain xterm title
        ;;
    esac
}

# Kitty's shell integration manages titles itself; only hook these elsewhere
if [[ -z "$KITTY_INSTALLATION_DIR" ]]; then
    autoload -Uz add-zsh-hook
    _title_precmd() { title "zsh" "%m: %~" }
    _title_preexec() { title "$1" "%m: $1" }
    add-zsh-hook precmd _title_precmd
    add-zsh-hook preexec _title_preexec
fi
