# Dotfiles

Personal development environment configuration for macOS and Ubuntu.

## Features

- **Cross-platform support**: Works on macOS and Ubuntu/Debian
- **Modular configuration**: Choose between minimal, standard, or full installation profiles
- **Safe linking by default**: Existing files are backed up; packages and
  system changes require explicit opt-in
- **Development tools**: Neovim, tmux, git, zsh, and more
- **Language support**: Go, Python, Rust, and more with full LSP integration

## Prerequisites

### macOS
The install scripts require **bash 4+**, but macOS ships bash 3.2 and
`bootstrap.sh` hard-exits without a newer bash. Install [Homebrew](https://brew.sh)
first, then bash, **before** running bootstrap:

```bash
# Install Homebrew (skip if already installed)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Install a modern bash (macOS stays on 3.2 forever)
brew install bash
```

## Quick Start

```bash
# Clone the repository
git clone https://github.com/a-kostevski/dotfiles.git ~/.dotfiles
cd ~/.dotfiles

# Link the minimal profile (the safe default; no packages or system settings)
./bootstrap.sh

# Or choose a specific profile
./bootstrap.sh --profile standard --verbose

# Install packages separately when you are ready
./bootstrap.sh --install-packages
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
- bat, ripgrep, and Python environment configuration

### Full
Complete development environment:
- Everything from Standard
- clang-format, curl, and LLDB configuration
- macOS-specific: Homebrew packages, Karabiner, Kitty terminal

### All
- `--profile all` symlinks every directory under `config/`

> **Note:** A `custom` profile name exists in the code, but the interactive
> component selector is not wired up. `--profile custom` currently just links
> the minimal set, so use `all` or a named profile instead.

## Usage

```bash
# View all options
./bootstrap.sh --help

# Dry run to preview changes
./bootstrap.sh --profile standard --dry-run

# Install OS packages (explicit opt-in)
./bootstrap.sh --profile full --install-packages

# Apply macOS defaults or security hardening (each is explicit and macOS-only)
./bootstrap.sh --apply-macos-defaults
./bootstrap.sh --harden

# Update symlinks only (no package installation)
./bootstrap.sh --sync

# Sync a single config
./bootstrap.sh --sync --config nvim

# Force overwrite without backups (use with caution)
./bootstrap.sh --force
```

Day-to-day symlink management uses the `dotfiles` utility (installed to `~/.local/bin`):

```bash
dotfiles sync      # reconcile the stored profile
dotfiles status    # profile-aware symlink health check (fails when unhealthy)
dotfiles clean     # remove broken links recorded in the dotfiles manifest
dotfiles profile   # show or switch the stored profile
dotfiles watch     # auto-sync on file changes (requires fswatch)
dotfiles uninstall # remove repo-owned symlinks and restore backups
```

Use `dotfiles clean --all` only when you intentionally want to remove every
broken symlink under `~/.config` and `~/.local/bin`; ordinary sync never
touches links it does not own.

`dotfiles uninstall` removes the symlinks this repo created and restores any
backups it made in their place:

```bash
dotfiles uninstall              # remove everything (prompts for confirmation)
dotfiles uninstall nvim git     # remove only the named configs' links
dotfiles uninstall --dry-run    # preview without changing anything
dotfiles uninstall --no-restore # remove links but skip backup restore
dotfiles uninstall --yes        # skip the confirmation prompt
```

## Repository Structure

```
.
├── .githooks/              # Git hooks (post-checkout, post-merge)
├── bin/                    # Utility scripts
├── config/                 # Application configurations
│   ├── bat/               # Better cat
│   ├── git/               # Git configuration
│   ├── nvim/              # Neovim configuration
│   ├── tmux/              # Tmux configuration
│   ├── zsh/               # Zsh configuration
│   └── ...                # Other tool configs
├── docs/                   # Design notes, plans, and review reports
├── install/               # OS-specific installation scripts
│   ├── install-macos.sh   # macOS setup
│   ├── install-ubuntu.sh  # Ubuntu setup
│   └── profiles.sh        # Profile definitions (PROFILE_CONFIGS)
├── tests/                 # Regression tests (make test)
├── Makefile               # install/update/test/validate targets
└── bootstrap.sh           # Main installation script
```

The current full-repository audit is documented in
[`docs/REVIEW-2026-07-14.md`](docs/REVIEW-2026-07-14.md). The older
[`docs/REVIEW-BACKLOG.md`](docs/REVIEW-BACKLOG.md) is retained as historical
review provenance and is not an authoritative list of current work.

## Configuration Details

### Zsh
- Modular configuration split into `rc.d/` and `profile.d/`
- Custom functions and completions
- Minimal plugin system using zsh-unplugged
- Performance-optimized with lazy loading

### Neovim
- Neovim **0.11.0 or newer** is required. Ubuntu package setup installs the
  pinned official 0.11.4 archive under `~/.local` when the distro package is
  too old.
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
- Deliberately minimal: mouse support, fast escape, and correct
  terminfo/truecolor (`tmux-256color` + `Tc` overrides)

## Platform-Specific Features

### macOS
- Homebrew package management (`--install-packages`)
- System defaults configuration (`--apply-macos-defaults`)
- Security hardening (`--harden`)
- Karabiner for keyboard customization
- Kitty terminal configuration

### Ubuntu
- APT package installation (`--install-packages`)
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

# Python provider for Neovim (pynvim). A plain `pip install` fails under
# PEP 668 on recent distros, so install it into a dedicated virtualenv:
python3 -m venv ~/.local/share/nvim-venv
~/.local/share/nvim-venv/bin/pip install pynvim

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
make update
# or: git pull --ff-only && dotfiles sync
```

`dotfiles sync` uses the stored profile. To change it, run
`dotfiles profile standard` (or `minimal`, `full`, or `all`) and then sync.

## Troubleshooting

### Permission Denied
If you get permission errors, ensure the scripts are executable:
```bash
chmod +x bootstrap.sh
chmod +x install/*.sh
```

### Broken Symlinks
The lifecycle commands clean only links owned by this repository:
```bash
dotfiles status
dotfiles clean

# Explicit global cleanup, if wanted:
dotfiles clean --all
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
Edit the `PROFILE_CONFIGS` map in `install/profiles.sh` (profile logic lives there, not in `bootstrap.sh`).

## Contributing

This is a personal configuration, but feel free to fork and adapt for your own use.

## License

MIT - See LICENSE file for details.
