# Dotfiles

Personal development environment configuration for macOS and Ubuntu.

## Features

- **Cross-platform support**: Works on macOS and Ubuntu/Debian
- **Modular configuration**: Choose between minimal, standard, or full installation profiles
- **Safe installation**: Automatic backup of existing files
- **Development tools**: Neovim, tmux, git, zsh, and more
- **Language support**: Go, Python, Rust, and more with full LSP integration

## Quick Start

```bash
# Clone the repository
git clone https://github.com/a-kostevski/dotfiles.git ~/.dotfiles
cd ~/.dotfiles

# Run bootstrap (minimal profile by default)
./bootstrap.sh

# Or choose a specific profile
./bootstrap.sh --profile standard --verbose
```

## Installation Profiles

### Minimal
Essential tools only - perfect for servers or minimal setups:
- Zsh with custom configuration
- Git with sensible defaults  
- Tmux configuration

### Standard
Common development setup:
- Everything from Minimal
- Neovim with full plugin ecosystem
- Development utilities (bat, ripgrep, fd)
- Python environment configuration

### Full
Complete development environment:
- Everything from Standard
- Language-specific tools (Go, Rust, etc.)
- macOS-specific: Homebrew packages, Karabiner, Kitty terminal
- Additional development utilities

## Usage

```bash
# View all options
./bootstrap.sh --help

# Dry run to preview changes
./bootstrap.sh --profile standard --dry-run

# Skip OS package installation
./bootstrap.sh --profile full --skip-install

# Force overwrite without backups (use with caution)
./bootstrap.sh --force
```

## Repository Structure

```
.
├── bin/                    # Utility scripts
├── config/                 # Application configurations
│   ├── bat/               # Better cat
│   ├── git/               # Git configuration
│   ├── nvim/              # Neovim configuration
│   ├── tmux/              # Tmux configuration
│   ├── zsh/               # Zsh configuration
│   └── ...                # Other tool configs
├── install/               # OS-specific installation scripts
│   ├── install-macos.sh   # macOS setup
│   └── install-ubuntu.sh  # Ubuntu setup
├── bootstrap.sh           # Main installation script
└── CLAUDE.md             # AI assistant instructions
```

## Configuration Details

### Zsh
- Modular configuration split into `rc.d/` and `profile.d/`
- Custom functions and completions
- Minimal plugin system using zsh-unplugged
- Performance-optimized with lazy loading

### Neovim
- Lazy.nvim for plugin management
- Full LSP support for multiple languages
- Modular plugin organization
- Custom keybindings and workflows
- AI integration (Copilot, Aider)

### Git
- Global gitignore patterns
- Sensible defaults
- Aliases for common operations

### Tmux
- Custom status bar
- Vim-like keybindings
- Session management

## Platform-Specific Features

### macOS
- Homebrew package management
- System defaults configuration
- Security hardening options
- Karabiner for keyboard customization
- Kitty terminal configuration

### Ubuntu
- APT package installation
- Essential development tools
- Compatibility aliases (fd, bat)

## Manual Steps

After installation, some manual steps may be required:

### Set Zsh as Default Shell
```bash
# Ubuntu/Debian
chsh -s $(which zsh)

# Then logout and login again
```

### Install Language-Specific Tools
```bash
# Go
go install golang.org/x/tools/gopls@latest

# Python
pip install --user pynvim

# Rust
rustup component add rust-analyzer
```

### Neovim Setup
First launch will automatically install plugins:
```bash
nvim
# Wait for plugin installation to complete
# Run :checkhealth to verify setup
```

## Updating

To update configurations:
```bash
cd ~/.dotfiles
git pull
./bootstrap.sh --profile <your-profile>
```

## Troubleshooting

### Permission Denied
If you get permission errors, ensure the scripts are executable:
```bash
chmod +x bootstrap.sh
chmod +x install/*.sh
```

### Broken Symlinks
The bootstrap script can detect and clean broken symlinks:
```bash
# During installation, you'll be prompted to clean broken links
# Or manually check:
find ~/.config -type l ! -exec test -e {} \; -print
```

### Zsh Not Found
On Ubuntu, if zsh is not found after installation:
```bash
# Ensure /etc/shells contains zsh path
grep -q "$(which zsh)" /etc/shells || echo "$(which zsh)" | sudo tee -a /etc/shells
```

## Customization

### Adding New Configurations
1. Add configuration to `config/<tool-name>/`
2. Update bootstrap script if needed
3. Document any special requirements

### Creating Custom Profiles
Edit `bootstrap.sh` and modify the `get_config_list()` function to define custom profiles.

## Contributing

This is a personal configuration, but feel free to fork and adapt for your own use.

## License

MIT - See LICENSE file for details.