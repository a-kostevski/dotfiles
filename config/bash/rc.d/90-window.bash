# Window title. Mirrors zsh/rc.d/90-window.zsh (precmd half only; bash has no
# clean preexec hook, so the title is not updated per running command).

# Kitty's shell integration manages titles itself; only hook these elsewhere
if [[ -z "${KITTY_INSTALLATION_DIR:-}" ]]; then
    __window_title() {
        local cwd="${PWD/#$HOME/\~}"
        case $TERM in
        screen* | tmux*)
            printf '\ekbash\e\\' # screen/tmux window title (in ^A")
            ;;
        xterm* | rxvt*)
            printf '\e]2;%s: %s\a' "${HOSTNAME%%.*}" "$cwd" # plain xterm title
            ;;
        esac
    }
    PROMPT_COMMAND="${PROMPT_COMMAND:+$PROMPT_COMMAND; }__window_title"
fi
