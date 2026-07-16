# Platform Detection Utilities
# Provides cross-platform compatibility functions for bash configuration
# (bash port of zsh/lib/platform.zsh; no command cache — bash 3.2 on macOS
# has no associative arrays, and `command -v` is cheap enough)

# Detect operating system
is_macos() {
  [[ "$OSTYPE" == darwin* ]]
}

is_linux() {
  [[ "$OSTYPE" == linux* ]]
}

# Check if command exists
command_exists() {
  command -v "$1" &>/dev/null
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
