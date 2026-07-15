# Platform Detection Utilities
# Provides cross-platform compatibility functions for zsh configuration

# Detect operating system
is_macos() {
  [[ "$OSTYPE" == darwin* ]]
}

is_linux() {
  [[ "$OSTYPE" == linux* ]]
}

# Command existence cache
typeset -gA _cmd_cache

# Check if command exists (positive results cached for performance)
command_exists() {
  local cmd="$1"

  # Positive results are cached; a present command rarely disappears mid-session.
  if (( ${+_cmd_cache[$cmd]} )); then
    return 0
  fi

  if command -v "$cmd" &>/dev/null; then
    _cmd_cache[$cmd]=0
    return 0
  fi
  # Do not cache the miss: a command installed later this session must be seen.
  return 1
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
