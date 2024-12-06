#!/usr/bin/env zsh

readonly SCRIPT_VERSION="1.0.0"
readonly SCRIPT_DATE="2024-01-17"

readonly MIN_MACOS_VERSION="10.15"
readonly LOGIN_MESSAGE="This system is monitored and restricted to authorized users only."
readonly LOG_DIR="${XDG_STATE_HOME:-$HOME/.local/state}"
readonly LOG_FILE="$LOG_DIR/macos_hardening.log"
readonly SLEEP_TIME=15
readonly DISPLAY_SLEEP_TIME=10
readonly HIBERNATE_MODE=25

log_security() {
   local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
   echo "[$timestamp] $1" | tee -a "$LOG_FILE"
   logger -p security.info "macOS hardening: $1"
}

handle_error() {
   local exit_code=$?
   local command=$1
   if [ $exit_code -ne 0 ]; then
      log_security "ERROR: Command failed: $command (exit code: $exit_code)"
      return 1
   fi
   return 0
}

check_compatibility() {
   if [[ $(sw_vers -productVersion) < "$MIN_MACOS_VERSION" ]]; then
      log_security "ERROR: Unsupported macOS version. Minimum required: $MIN_MACOS_VERSION"
      exit 1
   fi
}

# Backup current settings
backup_settings() {
   local backup_dir="/var/root/security_backup_$(date +%Y%m%d_%H%M%S)"
   log_security "Creating backup at $backup_dir"
   mkdir -p "$backup_dir"
   defaults read >"$backup_dir/defaults_backup.plist"
   pmset -g >"$backup_dir/pmset_backup.txt"
}

# Request user confirmation
confirm_changes() {
   echo "This script will modify system security settings."
   echo "Version: $SCRIPT_VERSION (Updated: $SCRIPT_DATE)"
   read -p "Do you want to continue? (y/N) " response
   [[ "$response" =~ ^[Yy]$ ]] || exit 0
}

# Initialize
username=$(id -un)
log_security "Starting macOS hardening for user: $username"
check_compatibility
confirm_changes
backup_settings

execute_command() {
   local cmd=$1
   local desc=$2
   log_security "Executing: $desc"
   eval "$cmd" || handle_error "$desc"
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

   for cmd in "${update_commands[@]}"; do
      execute_command "$cmd" "Configuring automatic updates"
   done
}

# Firewall
configure_firewall() {
   execute_command "/usr/bin/sudo /usr/bin/defaults write /Library/Preferences/com.apple.alf globalstate -int 1" "Enabling firewall"
   execute_command "/usr/bin/sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setstealthmode on" "Enabling stealth mode"
   execute_command "/usr/bin/sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setloggingmode on" "Enabling firewall logging"
   execute_command "/usr/bin/sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setloggingopt detail" "Setting detailed logging"
}

# System services
configure_services() {
   local services=(
      "system/com.apple.ODSAgent"
      "system/com.apple.screensharing"
      "system/com.apple.smbd"
      "system/com.apple.nfsd"
   )

   for service in "${services[@]}"; do
      execute_command "/usr/bin/sudo /bin/launchctl disable $service" "Disabling service: $service"
   done
}

# Security settings
configure_security() {
   # Password policy
   local password_policies=(
      "maxFailedLoginAttempts=5"
      "policyAttributeMinutesUntilFailedAuthenticationReset=15"
      "minChars=15"
      "requiresAlpha=1"
      "requiresNumeric=2"
      "requiresMixedCase=1"
      "usingHistory=15"
   )

   for policy in "${password_policies[@]}"; do
      execute_command "/usr/bin/sudo /usr/bin/pwpolicy -n /Local/Default -setglobalpolicy \"$policy\"" "Setting password policy: $policy"
   done
}

# Privacy settings
configure_privacy() {
   execute_command "/usr/bin/defaults write /Users/$username/Library/Preferences/com.apple.AdLib.plist allowApplePersonalizedAdvertising -bool false" "Disabling ad tracking"
   execute_command "/usr/bin/sudo /usr/bin/defaults write /Library/Preferences/com.apple.locationmenu.plist ShowSystemServices -bool true" "Configuring location services"
}

# Main execution
{
   configure_updates
   configure_firewall
   configure_services
   configure_security
   configure_privacy

   # System cleanup
   execute_command "/usr/bin/sudo /usr/bin/killall -HUP cfprefsd" "Refreshing system preferences"
   execute_command "/usr/bin/sudo /usr/bin/killall SystemUIServer" "Restarting SystemUIServer"
   execute_command "/usr/bin/sudo killall Finder" "Restarting Finder"

   unset username
   log_security "macOS hardening completed successfully"
   echo "Security hardening completed. Please restart your system."
} || {
   log_security "ERROR: Script execution failed"
   exit 1
}
