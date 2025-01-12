#!/usr/bin/env zsh

# Exit on error
set -e

# Script version and metadata
readonly SCRIPT_VERSION="1.0.0"
readonly SCRIPT_DATE="2024-01-17"
readonly SCRIPT_NAME=$(basename "$0")

# Configuration constants
readonly DEFAULT_CONFIG_DEST="${HOME}/.config"
readonly DEFAULT_BIN_DEST="${HOME}/.local/bin"

# Color constants for output
readonly COLOR_HEADER="\x1b[1;36m"
readonly COLOR_INFO="\x1b[34m"
readonly COLOR_ERROR="\x1b[31m"
readonly COLOR_SUCCESS="\x1b[32m"
readonly COLOR_RESET="\x1b[0m"

usage() {
  echo "Usage: $0 [-c|--config-dest <config_dest>] [-b|--bin-dest <bin_dest>] [-d|--dry-run] [-s|--skip-install]"
  echo "Options:"
  echo "  -c, --config-dest <config_dest>  Set the config directory (default: ~/.config)"
  echo "  -b, --bin-dest <bin_dest>        Set the bin directory (default: ~/.local/bin)"
  echo "  -d, --dry-run                    Perform a dry run without making any changes"
  echo "  -s, --skip-install               Skip running installation scripts"
  echo "  -v, --verbose                    Enable verbose output"
  echo "  -h, --help                       Display this help message"
  exit 1
}

declare config_dest
declare bin_dest
declare dry_run
declare verbose
declare skip_install
declare -r dot_root="$(cd "$(dirname "${0}")" && pwd -P)"

dot_title() {
  printf "\x1b[35m=>\x1b[0m $1\n"
}

dot_header() {
  printf "\x1b[1;36m$1\x1b[0m\n"
}

dot_info() {
  $verbose && printf "%2s\x1b[34m [Info]\x1b[0m$1\n"
}

dot_error() {
  printf "%2s\x1b[31m [Error]\x1b[0m$1\n"
}

dot_success() {
  printf "\x1b[32m [Success]\x1b[0m$1\n"
}

valid_os() {
  if [ $(uname -s) != "Darwin" ]; then
    echo "Script only supports macOS. Exiting..."
    exit 1
  fi
}

valid_paths() {
  [[ ! -d "$dot_root" ]] && dot_error "Invalid dotfiles root directory" && exit 1
  [[ ! -d "$config_src" ]] && dot_error "Invalid config source directory" && exit 1
  [[ ! -d "$bin_src" ]] && dot_error "Invalid bin source directory" && exit 1
}

dot_mkdir() {
  local dir="$1"
  if [[ ! -d "$dir" ]]; then
    dot_info "Creating directory $dir"
    $dry_run mkdir -p "$dir"
  fi
}

dot_mk_parent() {
  local target_file="$1"
  local parent_dir="$(dirname "$target_file")"
  [ -d "$parent_dir" ] || $dry_run mkdir -p "$parent_dir"
}

dot_link() {
  local src="$1"
  local dest="$2"

  [[ ! -e "$src" ]] && dot_error "Source $src does not exist" && return 1

  if [[ -L "${dest}" ]]; then
    local current_target
    current_target="$(readlink "${dest}")"
    [[ "$current_target" == "$src" ]] && dot_info "Link already exists: $dest" && return 0
    [[ -e "$dest" ]] && dot_error "Broken symlink detected: $dest" && return 1

  fi

  # Backup existing file/directory if it exists
  if [[ -e "${dest}" ]]; then
    local backup="${dest}.backup.$(date +%s)"
    dot_info "Backing up ${dest} to ${backup}"
    $dry_run mv "$dest" "$backup" || return 1
  fi

  # Create new symlink
  dot_info "Linking ${src} to ${dest}"
  $dry_run ln -sfn "$src" "$dest" || return 1
  return 0
}

link_config_dirs() {
  local config_src="$1"
  local config_dest="$2"
  local errors=0
  # HOME
  dot_link "$config_src/zsh/zshenv" "$HOME/.zshenv" || ((errors++))
  dot_link "$config_src/lldb/.lldbinit" "$HOME/.lldbinit" || ((errors++))

  # Loop through all directories in config_src
  while IFS= read -r file; do

    # Calculate relative path from config_src
    local rel_path="${file#$config_src/}"
    local dest_path="$config_dest/$rel_path"

    # Create parent directory if needed
    dot_mk_parent "$dest_path"

    # Create symlink
    dot_info "Processing $rel_path..."
    dot_link "$file" "$dest_path" || ((errors++))
  done < <(find "$config_src" -type f -not -name ".DS_Store")

  return $errors
}

link_bin_files() {
  local errors=0

  while IFS= read -r file; do
    dot_link "$file" "$bin_dest/$(basename "$file")" || ((errors++))
  done < <(find "$bin_src" -type f -not -name ".*")

  return $errors
}

run_install() {
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

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
    -c | --config-dest)
      if [[ -z "${2:-}" ]]; then
        echo "Error: config-dest requires a value"
        usage
      fi
      config_dest="${2}"
      shift 2
      ;;
    -b | --bin-dest)
      if [[ -z "${2:-}" ]]; then
        echo "Error: bin-dest requires a value"
        usage
      fi
      bin_dest="${2}"
      shift 2
      ;;
    -d | --dry-run)
      dry_run="echo"
      shift
      ;;
    -s | --skip-install)
      skip_install=true
      shift
      ;;
    -v | --verbose)
      verbose=true
      shift
      ;;
    -h | --help)
      usage
      ;;
    *)
      echo "Invalid argument: ${1}"
      usage
      ;;
    esac
    # shift
  done
}

valid_env() {
  # Check minimum required versions
  local min_bash_version="3.2"
  if ! version_check "${BASH_VERSION}" "${min_bash_version}"; then
    dot_error "Bash version ${min_bash_version} or higher required"
    exit 1
  }
  
  # Validate required commands
  local required_commands=("git" "curl" "sudo")
  for cmd in "${required_commands[@]}"; do
    if ! command -v "$cmd" >/dev/null; then
      dot_error "Required command not found: $cmd"
      exit 1
    fi
  done
}

# Main execution
main() {
  local exit_code=0

  valid_os
  valid_env

  verbose=${verbose:-false}
  # Set default values
  config_dest=${config_dest:-$DEFAULT_CONFIG_DEST}
  bin_dest=${bin_dest:-$DEFAULT_BIN_DEST}
  config_dest=$(realpath -m "$config_dest")
  bin_dest=$(realpath -m "$bin_dest")
  
  dry_run=${dry_run:-""}
  skip_install=${skip_install:-false}

  config_src="${dot_root}/config"
  bin_src="${dot_root}/bin"

  valid_paths

  # Create necessary directories
  dot_mkdir "$config_dest" || exit 1
  dot_mkdir "$bin_dest" || exit 1

  # Run installation if needed
  if ! $skip_install; then
    run_install_script "${dot_root}/install/install-macos.sh" || exit_code=1
  fi

  # Link configuration files
  dot_title "Symlinking config files..."
  link_config_dirs "$config_src" "$config_dest" || exit_code=1

  # Link binary files
  dot_info "Symlinking bin scripts..."
  link_bin_files || exit_code=1

  # Set final permissions
  if [[ -d "$bin_dest" ]]; then
    $dry_run chmod 0700 "$bin_dest"
    $dry_run find "$bin_dest" -type f -exec chmod 0700 {} \;
  fi

  if ((bin_errors > 0)); then
    dot_error "Some bin scripts failed to link"
    exit_code=1
  fi

  # Final status
  if ((exit_code == 0)); then
    dot_success "Installation completed successfully"
  else
    dot_error "Installation completed with errors"
  fi

  return $exit_code
}

parse_args "$@"
if ! main; then
  dot_error "Bootstrap failed"
  exit 1
fi

