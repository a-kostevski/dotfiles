# Interactive functions. bash has no autoload; the zsh functions/ directory
# is ported here as plain definitions.

# cd: list the directory after changing into it (zsh functions/cd)
cd() {
   builtin cd "$@" || return 1
   if command -v eza &>/dev/null; then
      eza -al --group-directories-first --no-permissions --no-filesize --no-time --no-user --icons
   fi
}

# mans: fuzzy-search man pages (zsh functions/mans)
mans() {
   command_exists fzf || { echo "mans: fzf not installed" >&2; return 1; }
   man -k . \
    | fzf -n1,2 --preview "echo {} \
    | cut -d' ' -f1 \
    | sed 's# (#.#' \
    | sed 's#)##' \
    | xargs -I% man %" --bind "enter:execute: \
      (echo {} \
      | cut -d' ' -f1 \
      | sed 's# (#.#' \
      | sed 's#)##' \
      | xargs -I% man % \
      | less -R)"
}

# src: guarded source helper (zsh functions/src)
src() {
    local mode=""
    local file=""

    while [[ "$#" -gt 0 ]]; do
        case "$1" in
            -f|--file)
                mode="file"
                file="$2"
                shift 2
                ;;
            -c|--cmd)
                mode="cmd"
                file="$2"
                shift 2
                ;;
            -x|--executable)
                mode="executable"
                file="$2"
                shift 2
                ;;
            -h|--help)
                echo "Usage: src [options] <file>"
                echo "Options:"
                echo "  -f, --file        Source file if it exists"
                echo "  -c, --cmd         Source command's init file if command exists"
                echo "  -x, --executable  Source file if it is executable"
                echo "  -h, --help        Show this help message"
                return 0
                ;;
            *)
                echo "Unknown option: $1"
                return 1
                ;;
        esac
    done

    if [[ -z "$file" ]]; then
        echo "No file specified"
        return 1
    fi

    case "$mode" in
        file)
            if [[ -f "$file" ]]; then
                # shellcheck disable=SC1090
                source "$file"
            else
                echo "File not found: $file"
                return 1
            fi
            ;;
        cmd)
            if command -v "$file" > /dev/null 2>&1; then
                # For commands, we typically source their init files
                # This is safer than arbitrary eval
                echo "Command exists: $file"
                echo "Note: Use 'source' directly to load configuration files"
            else
                echo "Command not found: $file"
                return 1
            fi
            ;;
        executable)
            if [[ -x "$file" ]]; then
                # shellcheck disable=SC1090
                source "$file"
            else
                echo "File is not executable: $file"
                return 1
            fi
            ;;
        *)
            echo "No mode specified"
            return 1
            ;;
    esac
}
