# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This is a personal dotfiles repository for macOS development environments. The repository uses a modular structure with configurations organized by application in the `config/` directory.

## Key Commands

### Initial Setup
```bash
# Run the bootstrap script with interactive profile selection
./bootstrap.sh

# Install with specific profile (minimal, standard, full)
./bootstrap.sh --profile standard

# Dry run to see what would be done
./bootstrap.sh --dry-run

# Skip installation scripts (only create symlinks)
./bootstrap.sh --skip-install

# Verbose output for debugging
./bootstrap.sh --dry-run --verbose --profile full
```

### Neovim Development
```bash
# Format Lua files in Neovim config
stylua config/nvim/

# Check Lua formatting
stylua --check config/nvim/
```

### Testing Changes
```bash
# Test bootstrap script without making changes
./bootstrap.sh --dry-run --verbose

# Clean broken symlinks
lnclean ~/.config
```

### Configuration Syncing
```bash
# Quick sync after making changes (symlinks only)
./bootstrap.sh --sync

# Alternative: use the dotfiles utility
dotfiles sync              # Update all symlinks
dotfiles clean             # Remove broken symlinks
dotfiles status            # Check symlink health
dotfiles watch             # Auto-sync on file changes

# Enable git hooks for automatic syncing
./.githooks/setup.sh       # Auto-sync on branch switches and pulls
```

## Architecture

### Bootstrap Process
The `bootstrap.sh` script is the main entry point that:
1. Detects OS (macOS, Ubuntu) and validates environment
2. **Interactive profile selection** if no profile specified
3. Creates standard directory structure (`~/.cache`, `~/.config`, `~/.local`, etc.)
4. Creates symlinks from `config/*` to `~/.config/*` based on profile
5. Creates symlinks from `bin/*` to `~/.local/bin/*` (standard/full profiles only)
6. Runs OS-specific installation scripts in `install/` directory
7. Handles backup of existing files with timestamps
8. Provides comprehensive dry-run mode and verbose logging

### Installation Profiles
- **minimal**: Essential configs only (git, zsh, tmux) + minimal Homebrew packages
- **standard**: Common development tools (+ nvim, basic tools) + minimal Homebrew packages  
- **full**: Everything including GUI apps and extras + full Homebrew packages
- **custom**: Interactive selection of individual components (via prompt)

### Neovim Configuration Structure
- **Entry**: `config/nvim/init.lua` → `lua/kostevski/init.lua`
- **Plugin Management**: Uses lazy.nvim with modular plugin organization
- **LSP Configs**: Individual server configs in `config/nvim/lsp/*.lua`
- **Utilities**: Helper functions in `lua/kostevski/utils/`
- **AI Integration**: Copilot and Aider configurations in `plugins/ai/`

### Modular Shell Configuration
- **Zsh**: Split into `rc.d/` (runtime) and `profile.d/` (login) directories
- **Functions**: Custom shell functions in `config/zsh/functions/`
- **Completions**: Custom completions in `config/zsh/completions/`

### Installation Scripts
The `install/` directory contains modular installation scripts:
- **`lib.sh`**: Shared library with common functions (output, validation, utilities)
- **`install-macos.sh`**: macOS-specific setup (Xcode tools, Rosetta 2, system defaults)
- **`install-ubuntu.sh`**: Ubuntu-specific setup (apt packages, symlink fixes)
- **`homebrew.sh`**: Homebrew package management integrated with profiles

All scripts use the shared library for consistent behavior, error handling, and dry-run support.

## Important Notes

- All configuration paths must be absolute when working with symlinks
- The bootstrap script creates timestamped backups of existing files before overwriting
- Cross-platform support for macOS and Ubuntu with OS-specific optimizations
- Neovim plugins are managed by lazy.nvim and auto-update on startup
- Language server configurations are in individual files under `config/nvim/lsp/`
- Security hardening for macOS is optional and can be applied separately
- Use `--dry-run` mode to test changes before applying them
- All install scripts support verbose logging with `--verbose` flag

### Syncing Configuration Changes
- **Quick Sync**: Run `./bootstrap.sh --sync` or `dotfiles sync` after making changes
- **Auto Sync**: Enable git hooks with `./.githooks/setup.sh` for automatic syncing
- **File Watching**: Use `dotfiles watch` to auto-sync on file changes (requires fswatch)
- **Broken Symlinks**: Clean with `dotfiles clean` or `lnclean ~/.config`
- **Health Check**: Run `dotfiles status` to verify all symlinks are correct

## Development Guidelines

### Script Improvements
When modifying bootstrap or install scripts:
- Use the shared library (`install/lib.sh`) for common functions
- Maintain consistent error handling and dry-run support
- Add file validation before sourcing configuration files
- Export variables early in bootstrap for proper script integration
- Follow the established output patterns (colors, prefixes)