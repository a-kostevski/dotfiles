#!/bin/zsh

usage() {
    echo "Usage: $0 [-c|--config-dest <config_dest>] [-b|--bin-dest <bin_dest>] [-d|--dry-run]"
    echo "Options:"
    echo "  -c, --config-dest <config_dest>  Set the config directory (default: $HOME/.config)"
    echo "  -b, --bin-dest <bin_dest>        Set the bin directory (default: $HOME/.local/bin)"
    echo "  -d, --dry-run                    Perform a dry run without making any changes"
    exit 1
}

if [ $(uname -s) != "Darwin" ]; then
    echo "Script only supports macOS. Exiting..."
    exit 1
fi

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
    -c | --config-dest)
        shift
        config_dest="$1"
        ;;
    -b | --bin-dest)
        shift
        bin_dest="$1"
        ;;
    -d | --dry-run)
        dry_run="echo"
        ;;
    *)
        echo "Invalid argument: $1"
        usage
        ;;
    esac
    shift
done

# Set default values if not provided
config_dest=${config_dest:-$HOME/.config}
bin_dest=${bin_dest:-$HOME/.local/bin}
dry_run=${dry_run:-""}

dot_root=$(pwd -P)
config_src=$dot_root/config
bin_src=$dot_root/bin

dot_title() {
    printf "\x1b[35m=>\x1b[0m $1\n"
}

dot_header() {
    printf "\x1b[1;36m$1\x1b[0m\n"
}

dot_info() {
    printf "%2s\x1b[34m [Info]\x1b[0m$1\n"
}

dot_error() {
    printf "%2s\x1b[31m [Error]\x1b[0m$1\n"
}

dot_success() {
    printf "\x1b[32m [Success]\x1b[0m$1\n"
}

dot_mkdir() {
    local dir="$1"
    if [[ ! -d "$dir" ]]; then
        dot_info "Creating directory $dir"
        $dry_run mkdir -p "$dir"
    fi
}

dot_link() {
    if [ -z $2 ]; then
        dot_info "Usage: $0 <src_file> <dst_file>"
        return
    fi
    local src=$1
    local dst=$2
    if [ ! -e $src ]; then
        dot_error "$src does not exist"
        return
    fi
    if [ -f $dst ] || [ -d $dst ]; then
        if [ -L $dst ]; then
            if [ "$(readlink $dst)" = $src ]; then
                dot_info "$(basename $src) already symlinked to $(dirname $dst)"
                return
            fi
        else
            dot_info "Backing up $dst to $dst-$(date +%Y-%m-%d-%H-%M-%S).backup"
            $dry_run mv $dst $dst-$(date +%Y-%m-%d-%H-%M-%S).backup
        fi
    fi
    $dry_run ln -s $src $dst
    dot_success "Symlinked $src to $dst"
}

dot_title "Initilizing macOS"

HOME=${HOME:-$(echo "/Users/$(whoami)")}

dot_mkdir $HOME/dev
dot_mkdir $HOME/dev/projects
dot_mkdir $HOME/dev/scripts
dot_mkdir $HOME/.cache
dot_mkdir $HOME/.config
dot_mkdir $HOME/.local
dot_mkdir $HOME/.local/bin
dot_mkdir $HOME/.local/share
dot_mkdir $HOME/.local/state
dot_mkdir $HOME/pictures/mac-screenshots

check_install() {
    target=$1
    install_cmd=$2
    if [[ ! $target ]]; then
        dot_info "$target could not be found, installing..."
        echo "$install_cmd"
    else
        dot_info "$target is already installed."
    fi
}

dot_header "Checking for command line tools"
check_install "$(xcode-select --version)" "xcode-select --install"

dot_header "Checking for Rosetta 2"
check_install "/Library/Apple/usr/share/rosetta/rosetta" "sudo softwareupdate --install-rosetta --agree-to-license"

dot_header "Checking for Homebrew"
if [[ $(uname -m)=="arm64" ]]; then
    brew_prefix="/opt/homebrew"
else
    brew_prefix="/usr/local"
fi

check_install "$brew_prefix/bin/brew" "/bin/bash -c \"$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""

eval $($brew_prefix/bin/brew shellenv)
unset brew_prefix

dot_header "Checking for zsh"
target_shell=$HOMEBREW_PREFIX/bin/zsh
check_install $target_shell "brew install zsh"

dot_header "Checking for Homebrew zsh as default shell"
current_shell=$(dscl . -read /Users/$USER UserShell | awk '{print $2}')
if [[ $current_shell != $target_shell ]]; then
    dot_info "Changing default shell to Homebrew zsh"
    # Appends the new shell to the list of allowed shells
    if ! grep -q $target_shell /private/etc/shells; then
        dot_info "Adding $target_shell to /private/etc/shells"
        echo $target_shell | sudo tee -a /private/etc/shells
    fi
    chsh -s $target_shell
    dot_success "Changed default shell to Homebrew zsh"
else
    dot_info "Default shell is already Homebrew zsh"
fi

export HOMEBREW_NO_ANALYTICS=1
export HOMEBREW_NO_INSECURE_REDIRECT=1
brew bundle --file=$dot_root/config/homebrew/Brewfile-min --no-upgrade

dot_title "Symlinking dotfiles..."
dot_link $config_src/zsh/zshenv $HOME/.zshenv
dot_link $config_src/zsh $config_dest/zsh

dot_link $config_src/git $config_dest/git

dot_link $config_src/nvim $config_dest/nvim

dot_link $config_src/python $config_dest/python

dot_link $config_src/lldb/.lldbinit $HOME/.lldbinit
dot_link $config_src/lldb/ $config_dest/lldb

dot_link $config_src/.curlrc $config_dest/.curlrc
dot_link $config_src/clang-format $config_dest/clang-format

dot_link $config_src/tmux $config_dest/tmux
dot_link $config_src/homebrew $config_dest/homebrew

for file in $bin_src/*; do
    dot_link $file $bin_dest/$file:t
done
