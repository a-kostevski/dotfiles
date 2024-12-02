#!/bin/zsh

set -e

usage() {
   echo "Usage: $0 [-c|--config-dest <config_dest>] [-b|--bin-dest <bin_dest>] [-d|--dry-run]"
   echo "Options:"
   echo "  -c, --config-dest <config_dest>  Set the config directory (default: ~/.config)"
   echo "  -b, --bin-dest <bin_dest>        Set the bin directory (default: ~/.local/bin)"
   echo "  -d, --dry-run                    Perform a dry run without making any changes"
   echo "  -h, --help                       Display this help message"
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
   -h | --help)
      usage
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

dot_root=$(cd "$(dirname "$0")" && pwd)
config_src="$dot_root/config"
bin_src="$dot_root/bin"

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
   local src="$1"
   local dest="$2"

   if [ -L "$dest" ] && [ "$(readlink "$dest")" = "$src" ]; then
      echo "Link already exists for $dest"
      return
   fi

   if [ -e "$dest" ] && [ ! -L "$dest" ]; then
      mv "$dest" "$dest.backup.$(date +%s)"
      echo "Backed up existing file $dest to $dest.backup.$(date +%s)"
   fi

   ln -s "$src" "$dest"
   echo "Linked $src to $dest"
}

check_install() {
   target=$1
   install_cmd=$2
   if [[ ! $target ]]; then
      dot_info "$target could not be found, installing..."
      echo "$install_cmd"
      dot_success "Installed $target"
   else
      dot_info "$target is already installed."
   fi
}
source install/install-macos.sh

dot_title "Symlinking dotfiles..."

dot_link "$config_src/zsh/zshenv" "$HOME/.zshenv"
dot_link "$config_src/zsh" "$config_dest/zsh"

dot_link "$config_src/git" "$config_dest/git"

dot_link "$config_src/nvim" "$config_dest/nvim"

dot_link "$config_src/python" "$config_dest/python"

dot_link "$config_src/lldb/.lldbinit" "$HOME/.lldbinit"
dot_link "$config_src/lldb/" "$config_dest/lldb"

dot_link "$config_src/.curlrc" "$config_dest/.curlrc"
dot_link "$config_src/clang-format" "$config_dest/clang-format"

dot_link "$config_src/tmux" "$config_dest/tmux"
dot_link "$config_src/homebrew" "$config_dest/homebrew"
dot_link "$config_src/kitty" "$config_dest/kitty"

dot_info "Symlinking bin scripts..."
for file in "$bin_src"/*; do
   dot_link "$file" "$bin_dest/$(basename "$file")"
done
