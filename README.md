# Dotfiles

My personal dotfiles for macOS development environment.

## Overview

This repository contains my personal dotfiles and scripts for setting up a new macOS system. It includes configurations for:

- Zsh (with custom prompt, aliases, and vim keybindings)
- Neovim
- Git
- Tmux
- Kitty terminal
- Various CLI tools

## Installation

1. Clone the repository:

```zsh
git clone https://github.com/a-kostevski/dotfiles.git
cd dotfiles
```

2. Run the bootstrap script:

```zsh
./bootstrap.sh
```

### Bootstrap Options

| Flag                 | Description                       | Default        |
| -------------------- | --------------------------------- | -------------- |
| `-c, --config-dest`  | Configuration files destination   | `~/.config`    |
| `-b, --bin-dest`     | Binary scripts destination        | `~/.local/bin` |
| `-d, --dry-run`      | Show what would be done           | `false`        |
| `-s, --skip-install` | Skip running installation scripts | `false`        |
| `-v, --verbose`      | Enable verbose output             | `false`        |
| `-h, --help`         | Show help message                 |                |

## Features

### Zsh Configuration

- Vi mode with enhanced keybindings
- Custom prompt with git integration
- Organized configuration with separate files for:
  - Aliases
  - Key bindings
  - Completions
  - History settings
  - Environment variables

### Scripts

The `bin/` directory contains utility scripts:

- `cantsleep` - Prepare system for focus mode
- `countdown` - Simple countdown timer
- `mkx` - Create executable script
- `lnclean` - Clean broken symlinks
- `osx_clock_toggle` - Toggle between analog/digital clock

### MacOS Configuration

Includes scripts for:

- Setting up macOS defaults
- Installing common development tools
- Configuring security settings

## Requirements

- macOS
- Git
- Curl
- Sudo access

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

Inspired by and borrowed from:

- [holman/dotfiles](https://github.com/holman/dotfiles)
- [mathiasbynens/dotfiles](https://github.com/mathiasbynens/dotfiles)
- [folke/dot](https://github.com/folke/dot)
- And many others in the dotfiles community. If you see your work here but aren't credited, please open an issue - I'd love to acknowledge your contribution!

---
