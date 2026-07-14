#!/usr/bin/env zsh
# Helper invoked by test-macos-defaults.sh with a temporary PlistBuddy stub.

set -eu

export HOME="$TEST_HOME"
source "$REPO_ROOT/config/macos/defaults.zsh"

plistbuddy() {
  "$TEST_PLISTBUDDY" "$@"
}

configure_finder_icon_info
