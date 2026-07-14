#!/usr/bin/env zsh

# macOS security hardening is intentionally a separate, explicitly requested
# operation. Every required command must succeed: a partial hardening run is
# reported as a failure, never as a successful completion.
set -euo pipefail

readonly SCRIPT_VERSION="1.1.0"
readonly SCRIPT_DATE="2026-07-14"
readonly MIN_MACOS_VERSION="10.15"
readonly LOGIN_MESSAGE="This system is monitored and restricted to authorized users only."
readonly LOG_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles"
readonly LOG_FILE="$LOG_DIR/macos_hardening.log"
readonly BACKUP_ROOT="$LOG_DIR/macos-hardening"
readonly SLEEP_TIME=15
readonly DISPLAY_SLEEP_TIME=10
readonly HIBERNATE_MODE=25

typeset -g LAST_BACKUP_DIR=""
typeset -g HARDENING_USERNAME=""

initialize_logging() {
   # Hardening logs and backups may describe the machine's security posture.
   # Keep them in user-owned storage and make them private before writing.
   umask 077
   mkdir -p "$LOG_DIR" || return 1
   chmod 700 "$LOG_DIR" || return 1
   touch "$LOG_FILE" || return 1
   chmod 600 "$LOG_FILE" || return 1
}

log_security() {
   local timestamp
   timestamp=$(date '+%Y-%m-%d %H:%M:%S')
   print -r -- "[$timestamp] $1" | tee -a "$LOG_FILE"
   # syslog is useful when it is available, but it is not a hardening action
   # and must not hide the result of the command being logged.
   command -v logger >/dev/null 2>&1 && logger -p security.info "macOS hardening: $1" || true
}

check_compatibility() {
   if [[ $(sw_vers -productVersion) < "$MIN_MACOS_VERSION" ]]; then
      log_security "ERROR: Unsupported macOS version. Minimum required: $MIN_MACOS_VERSION"
      return 1
   fi
}

# Back up the mutable state before changing it. The backup directory is owned
# by the invoking user, never /var/root, so it can be created before sudo work.
backup_settings() {
   local backup_dir

   umask 077
   mkdir -p "$BACKUP_ROOT" || {
      log_security "ERROR: Could not create backup root: $BACKUP_ROOT"
      return 1
   }
   chmod 700 "$BACKUP_ROOT" || {
      log_security "ERROR: Could not secure backup root: $BACKUP_ROOT"
      return 1
   }
   backup_dir=$(mktemp -d "$BACKUP_ROOT/security_backup_XXXXXXXX") || {
      log_security "ERROR: Could not create backup directory under: $BACKUP_ROOT"
      return 1
   }
   chmod 700 "$backup_dir" || return 1
   LAST_BACKUP_DIR="$backup_dir"
   log_security "Creating backup at $backup_dir"

   if ! defaults read >"$backup_dir/defaults_backup.plist"; then
      log_security "ERROR: Failed to back up user defaults"
      return 1
   fi
   if ! pmset -g >"$backup_dir/pmset_backup.txt"; then
      log_security "ERROR: Failed to back up power-management settings"
      return 1
   fi
}

# Request user confirmation. Return 2 for an intentional abort, and 1 when
# confirmation could not be read so callers never mistake EOF for approval.
confirm_changes() {
   local response
   echo "This script will modify system security settings."
   echo "Version: $SCRIPT_VERSION (Updated: $SCRIPT_DATE)"
   if ! read -r "response?Do you want to continue? (y/N) "; then
      log_security "ERROR: Could not read hardening confirmation"
      return 1
   fi
   [[ "$response" =~ ^[Yy]$ ]] || return 2
}

execute_command() {
   local cmd="$1"
   local desc="$2"
   log_security "Executing: $desc"
   if ! eval "$cmd"; then
      log_security "ERROR: Command failed: $desc"
      return 1
   fi
}

# Configure automatic updates
configure_updates() {
   local update_commands=(
      "/usr/bin/sudo /usr/bin/defaults write /Library/Preferences/com.apple.SoftwareUpdate AutomaticCheckEnabled -bool true"
      "/usr/bin/sudo /usr/bin/defaults write /Library/Preferences/com.apple.SoftwareUpdate AutomaticDownload -bool true"
      "/usr/bin/sudo /usr/bin/defaults write /Library/Preferences/com.apple.SoftwareUpdate AutomaticallyInstallMacOSUpdates -bool true"
      "/usr/bin/sudo /usr/bin/defaults write /Library/Preferences/com.apple.commerce AutoUpdate -bool true"
      "/usr/bin/sudo /usr/bin/defaults write /Library/Preferences/com.apple.SoftwareUpdate ConfigDataInstall -bool true"
      "/usr/bin/sudo /usr/bin/defaults write /Library/Preferences/com.apple.SoftwareUpdate CriticalUpdateInstall -bool true"
   )
   local cmd

   for cmd in "${update_commands[@]}"; do
      execute_command "$cmd" "Configuring automatic updates" || return 1
   done
}

# Firewall
configure_firewall() {
   execute_command "/usr/bin/sudo /usr/bin/defaults write /Library/Preferences/com.apple.alf globalstate -int 1" "Enabling firewall" || return 1
   execute_command "/usr/bin/sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setstealthmode on" "Enabling stealth mode" || return 1
   execute_command "/usr/bin/sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setloggingmode on" "Enabling firewall logging" || return 1
   execute_command "/usr/bin/sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setloggingopt detail" "Setting detailed logging" || return 1
}

# System services
configure_services() {
   local services=(
      "system/com.apple.ODSAgent"
      "system/com.apple.screensharing"
      "system/com.apple.smbd"
      "system/com.apple.nfsd"
   )
   local service

   for service in "${services[@]}"; do
      execute_command "/usr/bin/sudo /bin/launchctl disable $service" "Disabling service: $service" || return 1
   done
}

# Security settings
configure_security() {
   local password_policies=(
      "maxFailedLoginAttempts=5"
      "policyAttributeMinutesUntilFailedAuthenticationReset=15"
      "minChars=15"
      "requiresAlpha=1"
      "requiresNumeric=2"
      "requiresMixedCase=1"
      "usingHistory=15"
   )
   local policy

   for policy in "${password_policies[@]}"; do
      execute_command "/usr/bin/sudo /usr/bin/pwpolicy -n /Local/Default -setglobalpolicy \"$policy\"" "Setting password policy: $policy" || return 1
   done
}

# Privacy settings
configure_privacy() {
   execute_command "/usr/bin/defaults write /Users/$HARDENING_USERNAME/Library/Preferences/com.apple.AdLib.plist allowApplePersonalizedAdvertising -bool false" "Disabling ad tracking" || return 1
   execute_command "/usr/bin/sudo /usr/bin/defaults write /Library/Preferences/com.apple.locationmenu.plist ShowSystemServices -bool true" "Configuring location services" || return 1
}

run_hardening() {
   backup_settings || return 1
   configure_updates || return 1
   configure_firewall || return 1
   configure_services || return 1
   configure_security || return 1
   configure_privacy || return 1

   # These restarts are required for the changed settings to take effect.
   execute_command "/usr/bin/sudo /usr/bin/killall -HUP cfprefsd" "Refreshing system preferences" || return 1
   execute_command "/usr/bin/sudo /usr/bin/killall SystemUIServer" "Restarting SystemUIServer" || return 1
   execute_command "/usr/bin/sudo /usr/bin/killall Finder" "Restarting Finder" || return 1
}

main() {
   HARDENING_USERNAME=$(id -un)

   initialize_logging || {
      print -u2 -- "ERROR: Could not initialize macOS hardening log at $LOG_FILE"
      return 1
   }
   log_security "Starting macOS hardening for user: $HARDENING_USERNAME"
   check_compatibility || return 1

   if confirm_changes; then
      :
   else
      local confirmation_status=$?
      if [[ $confirmation_status -eq 2 ]]; then
         log_security "Hardening aborted by user"
         return 0
      fi
      return "$confirmation_status"
   fi

   if ! run_hardening; then
      log_security "ERROR: Script execution failed; backup retained at ${LAST_BACKUP_DIR:-$BACKUP_ROOT}"
      return 1
   fi

   log_security "macOS hardening completed successfully"
   echo "Security hardening completed. Please restart your system."
}

# A sourced hardening file is used only by the focused regression test. zsh
# changes $0 while sourcing, so use its evaluation context rather than $0.
if [[ "$ZSH_EVAL_CONTEXT" != *":file" ]]; then
   main "$@"
fi
