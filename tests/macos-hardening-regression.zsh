#!/usr/bin/env zsh
# Helper invoked by test-macos-hardening.sh with a temporary HOME and command
# stubs. It sources harden.zsh without executing its main function.

set -u

export HOME="$TEST_HOME"
export XDG_STATE_HOME="$TEST_STATE"
export PATH="$TEST_BIN:$PATH"
source "$REPO_ROOT/config/macos/harden.zsh"
setopt no_errexit

backup_settings
backup_status=$?
print -r -- "backup_status=$backup_status"
print -r -- "backup_dir=$LAST_BACKUP_DIR"
print -r -- "backup_defaults=$(<"$LAST_BACKUP_DIR/defaults_backup.plist")"
print -r -- "backup_pmset=$(<"$LAST_BACKUP_DIR/pmset_backup.txt")"
print -r -- "backup_mode=$(stat -f %Lp "$LAST_BACKUP_DIR" 2>/dev/null || stat -c %a "$LAST_BACKUP_DIR")"
print -r -- "backup_file_mode=$(stat -f %Lp "$LAST_BACKUP_DIR/defaults_backup.plist" 2>/dev/null || stat -c %a "$LAST_BACKUP_DIR/defaults_backup.plist")"

execute_command "false" "intentional test failure"
command_status=$?
print -r -- "command_status=$command_status"

calls=()
backup_settings() { calls+=(backup); return 1; }
configure_updates() { calls+=(updates); return 0; }
run_hardening
backup_failure_status=$?
print -r -- "backup_failure_status=$backup_failure_status"
print -r -- "backup_failure_calls=${(j:,:)calls}"

calls=()
backup_settings() { calls+=(backup); return 0; }
configure_updates() { calls+=(updates); return 1; }
configure_firewall() { calls+=(firewall); return 0; }
configure_services() { calls+=(services); return 0; }
configure_security() { calls+=(security); return 0; }
configure_privacy() { calls+=(privacy); return 0; }
execute_command() { calls+=(cleanup); return 0; }
run_hardening
hardening_status=$?
print -r -- "hardening_status=$hardening_status"
print -r -- "calls=${(j:,:)calls}"
