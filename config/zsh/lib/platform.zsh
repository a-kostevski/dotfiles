# Platform Detection Utilities
# Provides cross-platform compatibility functions for zsh configuration

# Detect operating system
is_macos() {
  [[ "$OSTYPE" == darwin* ]]
}

is_linux() {
  [[ "$OSTYPE" == linux* ]]
}

is_ubuntu() {
  [[ -f /etc/os-release ]] && grep -q "^ID=ubuntu" /etc/os-release
}

# Check if running on ARM architecture
is_arm() {
  [[ "$(uname -m)" == "arm64" ]] || [[ "$(uname -m)" == "aarch64" ]]
}

# Check if command exists
command_exists() {
  command -v "$1" &>/dev/null
}

# Get clipboard copy command
get_clipboard_copy() {
  if is_macos; then
    echo "pbcopy"
  elif command_exists xclip; then
    echo "xclip -selection clipboard"
  elif command_exists wl-copy; then
    echo "wl-copy"
  else
    echo ""
  fi
}

# Get clipboard paste command
get_clipboard_paste() {
  if is_macos; then
    echo "pbpaste"
  elif command_exists xclip; then
    echo "xclip -selection clipboard -o"
  elif command_exists wl-paste; then
    echo "wl-paste"
  else
    echo ""
  fi
}

# Get file open command
get_open_command() {
  if is_macos; then
    echo "open"
  elif command_exists xdg-open; then
    echo "xdg-open"
  else
    echo ""
  fi
}

# Get dircolors command
get_dircolors_command() {
  if is_macos && command_exists gdircolors; then
    echo "gdircolors"
  elif command_exists dircolors; then
    echo "dircolors"
  else
    echo ""
  fi
}

# Get file modification time (for cache checking)
get_file_mtime() {
  local file="$1"
  if [[ ! -e "$file" ]]; then
    echo "0"
    return
  fi

  if is_macos; then
    stat -f "%m" "$file" 2>/dev/null || echo "0"
  else
    stat -c "%Y" "$file" 2>/dev/null || echo "0"
  fi
}

# Get current day of year (for cache checking)
get_day_of_year() {
  date +"%j"
}

# Export platform info for use in other scripts
export PLATFORM_OS="$(uname -s | tr '[:upper:]' '[:lower:]')"
export PLATFORM_ARCH="$(uname -m)"
