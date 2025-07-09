#!/usr/bin/env bash
# Setup git hooks for automatic dotfiles syncing

set -euo pipefail

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RESET='\033[0m'

echo "🔧 Setting up git hooks for automatic dotfiles syncing..."

# Configure git to use our hooks directory
git config core.hooksPath .githooks

echo -e "${GREEN}✓${RESET} Git hooks configured successfully!"
echo
echo "The following hooks are now active:"
echo "  • post-checkout: Auto-sync when switching branches"
echo "  • post-merge:    Auto-sync after pulling changes"
echo
echo -e "${YELLOW}Note:${RESET} To disable hooks, run: git config --unset core.hooksPath"