# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This is a personal dotfiles repository for macOS development environments. The repository uses a modular structure with configurations organized by application in the `config/` directory.

## Key Commands

### Initial Setup
```bash
# Run the bootstrap script to symlink all configurations
./bootstrap.sh

# Dry run to see what would be done
./bootstrap.sh --dry-run

# Skip installation scripts (only create symlinks)
./bootstrap.sh --skip-install
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

## Architecture

### Bootstrap Process
The `bootstrap.sh` script is the main entry point that:
1. Creates symlinks from `config/*` to `~/.config/*`
2. Creates symlinks from `bin/*` to `~/.local/bin/*`
3. Handles backup of existing files
4. Runs installation scripts in `install/` directory
5. Provides dry-run mode for testing

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
- `install/install-macos.sh`: Sets up macOS defaults and directory structure
- `install/homebrew.sh`: Manages package installation with minimal/full profiles

## Important Notes

- All configuration paths must be absolute when working with symlinks
- The bootstrap script creates backups of existing files before overwriting
- Neovim plugins are managed by lazy.nvim and auto-update on startup
- Language server configurations are in individual files under `config/nvim/lsp/`
- Security hardening for macOS is optional and can be applied separately