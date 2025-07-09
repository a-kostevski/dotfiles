#!/usr/bin/env bash

# Profile Management Module for Dotfiles
# Version: 1.0.0

# Source shared library if not already loaded
if [[ -z "${dot_title:-}" ]]; then
  source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
fi

# Profile definitions
declare -gA PROFILE_CONFIGS=(
  ["minimal"]="git zsh tmux"
  ["standard"]="git zsh tmux nvim bat python"
  ["full"]="git zsh tmux nvim bat python clang-format lldb"
)

# Global array for custom configurations
declare -ga CUSTOM_CONFIGS=()

# OS-specific additions for full profile
declare -gA PROFILE_OS_SPECIFIC=(
  ["macos_full"]="homebrew karabiner kitty"
  ["ubuntu_full"]=""
)

# Get all existing configs from the config directory
get_all_existing_configs() {
  # Try CONFIG_DIR first, then dot_root/config, then relative to this script
  local config_dir="${CONFIG_DIR:-}"
  if [[ -z "$config_dir" ]] && [[ -n "${dot_root:-}" ]]; then
    config_dir="$dot_root/config"
  fi
  if [[ -z "$config_dir" ]] || [[ ! -d "$config_dir" ]]; then
    # Fallback to relative path from this script
    local script_dir
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    config_dir="$script_dir/../config"
  fi

  local -a configs=()

  # Debug output
  >&2 echo "[DEBUG] get_all_existing_configs: config_dir=$config_dir"
  >&2 echo "[DEBUG] Directory exists: $([[ -d "$config_dir" ]] && echo "yes" || echo "no")"

  # Find all directories in the config directory
  if [[ -d "$config_dir" ]]; then
    while IFS= read -r dir; do
      local config_name
      config_name=$(basename "$dir")
      # Skip hidden directories and special cases
      if [[ ! "$config_name" =~ ^\. ]]; then
        configs+=("$config_name")
      fi
    done < <(find "$config_dir" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sort)
  fi

  >&2 echo "[DEBUG] Found ${#configs[@]} configs: ${configs[*]}"

  printf '%s\n' "${configs[@]}"
}

# Get config list based on profile and OS
get_config_list() {
  local profile="${1:-${PROFILE:-minimal}}"
  local os_type="${2:-${OS_TYPE:-}}"
  local -a configs=()

  # All profile - return all existing configs
  if [[ "$profile" == "all" ]]; then
    >&2 echo "[DEBUG] get_config_list: profile=all detected"
    local -a all_configs=()
    local config_line

    # Read configs into array to handle empty output properly
    while IFS= read -r config_line; do
      if [[ -n "$config_line" ]]; then
        all_configs+=("$config_line")
      fi
    done < <(get_all_existing_configs)

    >&2 echo "[DEBUG] get_config_list: found ${#all_configs[@]} configs"

    if [[ ${#all_configs[@]} -gt 0 ]]; then
      >&2 echo "[DEBUG] get_config_list: configs: ${all_configs[*]}"
      printf '%s\n' "${all_configs[@]}"
    else
      # Fallback to minimal if no configs found
      >&2 echo "[DEBUG] get_config_list: No configs found, falling back to minimal"
      dot_warning "No configs found in directory, falling back to minimal"
      configs=("${PROFILE_CONFIGS["minimal"]}")
      printf '%s\n' "${configs[@]}"
    fi
    return 0
  # Custom profile - use selected components
  elif [[ "$profile" == "custom" ]]; then
    if [[ ${#CUSTOM_CONFIGS[@]} -gt 0 ]]; then
      configs=("${CUSTOM_CONFIGS[@]}")
    else
      # Fallback to minimal if no custom configs
      configs=("${PROFILE_CONFIGS["minimal"]}")
    fi
  else
    # Get base configs for profile
    if [[ -n "${PROFILE_CONFIGS[$profile]}" ]]; then
      configs=("${PROFILE_CONFIGS[$profile]}")
    else
      dot_error "Unknown profile: $profile"
      return 1
    fi

    # Add OS-specific configs for full profile
    if [[ "$profile" == "full" ]] && [[ -n "$os_type" ]]; then
      local os_key="${os_type}_full"
      if [[ -n "${PROFILE_OS_SPECIFIC[$os_key]}" ]]; then
        configs+=("${PROFILE_OS_SPECIFIC[$os_key]}")
      fi
    fi
  fi

  printf '%s\n' "${configs[@]}"
}

# Detect current profile based on existing symlinks
detect_current_profile() {
  local config_dest="${1:-$HOME/.config}"
  local -a detected_configs=()

  for config_dir in "$config_dest"/*; do
    # Skip if the item doesn't exist (in case of no matches)
    [[ -e "$config_dir" ]] || continue

    # Check if the directory itself is a symlink
    if [[ -L "$config_dir" ]]; then
      local config_name
      config_name=$(basename "$config_dir")
      detected_configs+=("$config_name")
      continue
    fi

    # Check if any contents are symlinks
    if [[ -d "$config_dir" ]]; then
      for item in "$config_dir"/*; do
        if [[ -L "$item" ]]; then
          local config_name
          config_name=$(basename "$config_dir")
          detected_configs+=("$config_name")
          break
        fi
      done
    fi
  done

  # Match detected configs against known profiles
  # Check for full profile indicators
  for config in "${detected_configs[@]}"; do
    case "$config" in
      kitty | karabiner | homebrew | lldb | clang-format)
        echo "full"
        return 0
        ;;
    esac
  done

  # Check for standard profile indicators
  for config in "${detected_configs[@]}"; do
    case "$config" in
      nvim | bat | python)
        echo "standard"
        return 0
        ;;
    esac
  done

  # Check for minimal profile
  for config in "${detected_configs[@]}"; do
    case "$config" in
      git | zsh | tmux)
        echo "minimal"
        return 0
        ;;
    esac
  done

  echo ""
}

# Interactive profile selection
select_profile() {
  dot_title "Select Installation Profile"
  echo
  echo "Choose which profile to install:"
  echo
  echo "  ${COLOR_INFO}1) minimal${COLOR_RESET}  - Essential configs only"
  echo "     └─ git, zsh, tmux"
  echo
  echo "  ${COLOR_INFO}2) standard${COLOR_RESET} - Common development tools"
  echo "     └─ minimal + nvim, bat, python"
  echo
  echo "  ${COLOR_INFO}3) full${COLOR_RESET}     - Everything including GUI apps"
  echo "     └─ standard + kitty, karabiner, homebrew packages"
  echo
  echo "  ${COLOR_INFO}4) custom${COLOR_RESET}   - Choose individual components"
  echo

  local choice
  while true; do
    printf "Select profile [1-4]: "
    read -r choice

    case "$choice" in
      1)
        PROFILE="minimal"
        dot_success "Selected: minimal profile"
        break
        ;;
      2)
        PROFILE="standard"
        dot_success "Selected: standard profile"
        break
        ;;
      3)
        PROFILE="full"
        dot_success "Selected: full profile"
        break
        ;;
      4)
        select_custom_components
        break
        ;;
      *)
        dot_error "Invalid choice. Please enter 1, 2, 3, or 4."
        ;;
    esac
  done
  echo

  export PROFILE
}

# Interactive custom component selection
select_custom_components() {
  dot_title "Custom Component Selection"
  echo
  echo "Select which components to install:"
  echo

  # Start with minimal configs
  local -a selected_configs=("git" "zsh" "tmux")

  # Get all available configs dynamically, excluding minimal ones
  local -a all_existing=()
  local config_line
  while IFS= read -r config_line; do
    if [[ -n "$config_line" ]]; then
      # Skip configs already in minimal
      if [[ "$config_line" != "git" && "$config_line" != "zsh" && "$config_line" != "tmux" ]]; then
        all_existing+=("$config_line")
      fi
    fi
  done < <(get_all_existing_configs)

  # Sort the configs for consistent presentation
  local -a available_configs=()
  if [[ ${#all_existing[@]} -gt 0 ]]; then
    IFS=$'\n' available_configs=($(sort <<<"${all_existing[*]}"))
    unset IFS
  fi

  for config in "${available_configs[@]}"; do
    # Skip OS-specific configs if not applicable
    case "$config" in
      kitty | karabiner | homebrew)
        [[ "${OS_TYPE:-}" != "macos" ]] && continue
        ;;
    esac

    printf "Install %s? [y/N]: " "$config"
    read -r response
    if [[ "$response" =~ ^[Yy]$ ]]; then
      selected_configs+=("$config")
      dot_success "Added: $config"
    fi
  done

  # Set custom profile
  PROFILE="custom"
  CUSTOM_CONFIGS=("${selected_configs[@]}")

  echo
  dot_success "Custom profile created with: ${selected_configs[*]}"

  # Export only PROFILE (arrays cannot be exported)
  export PROFILE
}

# Profile selection with current detection option
select_profile_with_current() {
  local current_profile
  current_profile=$(detect_current_profile "$@")

  dot_title "Select Installation Profile"
  echo
  echo "Choose which profile to sync:"
  echo
  echo "  ${COLOR_INFO}1) minimal${COLOR_RESET}  - Essential configs only"
  echo "     └─ git, zsh, tmux"
  echo
  echo "  ${COLOR_INFO}2) standard${COLOR_RESET} - Common development tools"
  echo "     └─ minimal + nvim, bat, python"
  echo
  echo "  ${COLOR_INFO}3) full${COLOR_RESET}     - Everything including GUI apps"
  echo "     └─ standard + kitty, karabiner, homebrew packages"
  echo

  if [[ -n "$current_profile" ]]; then
    echo "  ${COLOR_INFO}4) current${COLOR_RESET}  - Use current profile ($current_profile)"
  else
    echo "  ${COLOR_INFO}4) current${COLOR_RESET}  - Use current profile (not detected, will use minimal)"
  fi
  echo
  echo "  ${COLOR_INFO}5) all${COLOR_RESET}      - Sync all existing configs"
  local all_configs_list
  all_configs_list=$(get_all_existing_configs | xargs | sed 's/ /, /g')
  if [[ -n "$all_configs_list" ]]; then
    echo "     └─ $all_configs_list"
  else
    echo "     └─ (no configs found)"
  fi
  echo

  local choice
  while true; do
    printf "Select profile [1-5]: "
    read -r choice

    case "$choice" in
      1)
        dot_success "Selected: minimal profile"
        echo "minimal"
        return 0
        ;;
      2)
        dot_success "Selected: standard profile"
        echo "standard"
        return 0
        ;;
      3)
        dot_success "Selected: full profile"
        echo "full"
        return 0
        ;;
      4)
        if [[ -n "$current_profile" ]]; then
          dot_info "Using current profile: $current_profile"
          echo "$current_profile"
        else
          dot_warning "Could not detect current profile, using minimal"
          echo "minimal"
        fi
        return 0
        ;;
      5)
        dot_success "Selected: all existing configs"
        echo "all"
        return 0
        ;;
      *)
        dot_error "Invalid choice. Please enter 1, 2, 3, 4, or 5."
        ;;
    esac
  done
}

# Validate profile
validate_profile() {
  local profile="$1"

  case "$profile" in
    minimal | standard | full | custom | all)
      return 0
      ;;
    *)
      dot_error "Invalid profile: $profile"
      dot_error "Valid profiles: minimal, standard, full, custom, all"
      return 1
      ;;
  esac
}

# Get profile description
get_profile_description() {
  local profile="$1"

  case "$profile" in
    minimal)
      echo "Essential configs only (git, zsh, tmux)"
      ;;
    standard)
      echo "Common development tools (minimal + nvim, bat, python)"
      ;;
    full)
      echo "Everything including GUI apps"
      ;;
    custom)
      echo "Custom selection of components"
      ;;
    all)
      echo "All existing configs in the config directory"
      ;;
    *)
      echo "Unknown profile"
      ;;
  esac
}

