# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

Personal dotfiles for development environment configuration across macOS and Ubuntu. Linking is driven by four link profiles (`minimal`, `standard`, `full`, `all`) that select which configs get symlinked. Package installation is a separate, opt-in concern with its own tiers (`minimal`, `standard`, `full`); a plain `./bootstrap.sh` is link-only and installs nothing.

## Development Commands

### Installation and Updates

```bash
# Bootstrap: link-only by default (installs no packages, changes no system state)
./bootstrap.sh                           # Link the minimal profile
./bootstrap.sh --profile standard        # Link a specific profile
./bootstrap.sh --dry-run                 # Preview changes
./bootstrap.sh --sync                    # Update symlinks only (skip install)
./bootstrap.sh --verbose                 # Verbose output

# Opt-in mutations (each explicit; macOS-only ones prompt for sudo)
./bootstrap.sh --install-packages        # Install OS packages (tier via --packages)
./bootstrap.sh --apply-macos-defaults    # Write macOS defaults (incl. Touch ID PAM on 14+)
./bootstrap.sh --harden                  # Apply macOS security hardening

# Using Makefile
make install                             # Link minimal profile (PROFILE overrides)
make install-standard                    # Link standard profile
make install-full                        # Link full profile
make update                              # git pull --ff-only, then dotfiles sync (no reinstall)
make PROFILE=standard VERBOSE=true install  # Custom options
```

### Symlink Management

```bash
# Using the dotfiles utility (in bin/)
dotfiles sync                            # Update symlinks
dotfiles clean                           # Remove broken symlinks
dotfiles status                          # Check symlink status

# Manual symlink checks
make validate                            # Find broken symlinks
make clean                               # Remove broken symlinks
```

### Testing and Validation

```bash
make deps                                # Check for required dependencies
make validate                            # Check for broken symlinks
make backup                              # Backup current configurations
```

## Architecture

### Core Entry Points

- **bootstrap.sh**: Main entry point — OS detection and symlink creation by default; package installation and macOS provisioning only when their opt-in flags are passed
- **bin/dotfiles**: Utility script for day-to-day symlink management (sync, clean, status)
- **Makefile**: High-level commands for common tasks

### Directory Structure

```
config/                    # All configuration files
├── nvim/                 # Neovim configuration (Lua-based)
│   ├── init.lua         # Entry point, loads kostevski module
│   ├── lua/kostevski/   # Main configuration module
│   │   ├── config/      # Options, keymaps, autocmds, lazy.nvim setup
│   │   ├── plugins/     # Plugin configurations (organized by category)
│   │   └── utils/       # Utility functions
│   └── lsp/             # LSP server configurations
├── zsh/                 # Zsh configuration
│   ├── zshenv           # Environment variables (loaded first)
│   ├── .zshrc           # Interactive shell setup
│   ├── rc.d/            # Modular rc configurations (numbered for load order)
│   ├── profile.d/       # Profile configurations
│   ├── functions/       # Autoloadable functions
│   └── lib/             # Shared library functions
├── git/                 # Git configuration
├── tmux/                # Tmux configuration
└── [other tools]/       # Other tool-specific configs

install/                  # Installation scripts
├── lib.sh               # Shared utility functions
├── symlinks.sh          # Symlink management functions
├── install-macos.sh     # macOS-specific installation
├── install-ubuntu.sh    # Ubuntu-specific installation
└── homebrew.sh          # Homebrew package management

bin/                      # Utility scripts
└── dotfiles             # Main utility script for symlink management
```

### Configuration Management

The dotfiles use a **symlink-based system** driven by a declarative manifest:
- `manifest.conf` is the source of truth: entries are grouped under
  cumulative profile sections (`[minimal]` ⊂ `[standard]` ⊂ `[full]`), one
  line per entry (`name kind src dest [platforms]`), and `install/manifest.sh`
  parses it
- `bootstrap.sh` link, `dotfiles status`, and `dotfiles uninstall` all derive
  their file set from the manifest — none of them hardcode a symlink list
- Config files in `config/` are symlinked to `~/.config/` (or another `dest`
  per the entry, e.g. `{HOME}` for dotfiles like `~/.zshenv`)
- Existing files are automatically backed up before being replaced
- `~/.config/.dotfiles-manifest` remains the runtime record of symlinks
  actually created; it is separate from `manifest.conf`, the
  declarative source

### Neovim Architecture

- **Plugin Manager**: lazy.nvim
- **Entry Flow**: `init.lua` → `kostevski/init.lua` → `kostevski/config/init.lua`
- **Load Order**: options → autocmds → keymaps → lazy.nvim → plugins
- **Organization**: Plugins are organized by category (coding, editor, lsp, tools, ui, ai, lang)
- **Utils Module**: Global `Utils` object provides shared functionality across all configs

### Zsh Architecture

- **Modular Loading**: Files in `rc.d/` are loaded in numerical order (00-, 10-, 20-, etc.)
- **Key Files**:
  - `00-platform.zsh`: Platform detection
  - `10-config.zsh`: Core configuration
  - `20-exports.zsh`: Environment variables
  - `30-completions.zsh`: Completion system
  - `40-history.zsh`: History configuration
  - `50-keybindings.zsh`: Key bindings
  - `60-aliases.zsh`: Aliases
  - `70-zsh-unplugged.zsh`: Plugin system
  - `71-plugins.zsh`: Plugin loading
  - `80-prompt.zsh`: Prompt configuration
  - `90-window.zsh`: Window title
- **Plugin System**: Uses zsh-unplugged for minimal plugin management
- **Platform-Specific**: Handles differences between macOS and Ubuntu

## Testing and Validation

### Lua Syntax

```bash
# Check Neovim Lua configuration syntax
luac -p config/nvim/**/*.lua
```

### Shell Scripts

```bash
# Make scripts executable (if needed)
chmod +x bootstrap.sh
chmod +x install/*.sh
chmod +x bin/*

# Lint shell scripts (if shellcheck is installed)
shellcheck bootstrap.sh install/*.sh
```

### Neovim Health Checks

```bash
# Launch Neovim and run health checks
nvim
:checkhealth
```

## Important Patterns

### When Modifying Configurations

1. **Never modify files in `~/.config/` directly** - Always edit source files in this repository's `config/` directory
2. **Run sync after changes**: `./bootstrap.sh --sync` or `dotfiles sync`
3. **Use numbered prefixes** in `zsh/rc.d/` to control load order (00, 10, 20, etc.)
4. **Test Lua syntax** before committing: `luac -p config/nvim/lua/**/*.lua`

### Adding New Configurations

1. Add configuration files to `config/<tool-name>/`
2. Add a matching line under the right profile section in
   `manifest.conf` (`name kind src dest [platforms]`; platforms
   defaults to `all`) — `bootstrap.sh`, `dotfiles status`, and
   `dotfiles uninstall` all pick it up automatically once declared there
3. No need to manually update symlink logic in any script

### Adding a Package

Packages are declarative and independent of the link manifest above:

1. Add a line under the right tier section in `packages.conf`
   (`name brew cask apt`; sections are cumulative `[minimal]` ⊂ `[standard]`
   ⊂ `[full]`; use `-` to skip a field for a given platform)
2. No script changes needed — `install/packages.sh` (`packages_select`)
   is read by `install/homebrew.sh` (macOS Brewfile generation) and
   `install/install-ubuntu.sh` (`ubuntu_required_apt`) automatically

### Neovim Plugin Development

- New plugins go in `config/nvim/lua/kostevski/plugins/` organized by category
- Plugin files return lazy.nvim spec tables
- Category files (e.g., `coding.lua`, `editor.lua`) aggregate related plugins
- LSP configurations go in `config/nvim/lsp/<server-name>.lua`
- Use the global `Utils` object for common functionality

### OS-Specific Code

- Platform detection: call `detect_os` from `install/lib.sh`, then check the exported `OS_TYPE` (`macos`/`ubuntu`/`unsupported`) and `OS_VERSION` variables
- Zsh has platform detection in `config/zsh/rc.d/00-platform.zsh` (`is_macos`/`is_linux` helpers in `config/zsh/lib/platform.zsh`)
