# Dotfiles

Personal development environment configuration for macOS and Ubuntu.

## Features

- **Cross-platform support**: Works on macOS and Ubuntu/Debian
- **Modular configuration**: Choose between minimal, standard, full, or all link profiles
- **Safe linking by default**: A plain `./bootstrap.sh` only symlinks configs
  (existing files are backed up). Every system-mutating action is a separate
  opt-in flag — see [What the opt-in flags change](#what-the-opt-in-flags-change)
- **Independent package tiers**: `--install-packages` installs OS packages
  separately from linking, defaulting to the link profile's tier but
  overridable with `--packages`
- **Development tools**: Neovim, tmux, git, zsh, and more
- **Language support**: LSP integration for many languages. Neovim enables
  Lua, Terraform, and C++ by default; enable more in
  `config/nvim/lua/kostevski/config/languages.lua`

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

## What the opt-in flags change

A plain `./bootstrap.sh` is link-only: it creates symlinks and backs up any
files it would overwrite. Nothing else is touched unless you pass one of these:

- `--install-packages` — installs OS packages for the selected tier
  (see [Package Installation](#package-installation)).
- `--apply-macos-defaults` *(macOS only)* — **prompts for sudo**, writes system
  and UI preferences, and on macOS 14+ appends a Touch ID entry to
  `/etc/pam.d/sudo_local` (PAM). Skipped on older macOS or when the PAM
  template is absent.
- `--harden` *(macOS only)* — **prompts for sudo** and applies security
  hardening (`config/macos/harden.zsh`).
- `dotfiles clean --all` — removes **every** broken symlink under `~/.config`
  and `~/.local/bin`. Ordinary sync/clean only touch links this repo owns.

## Installation Profiles

`profile` (`minimal | standard | full | all`) selects which configs get
**symlinked** — it does not install any packages. Package installation is a
separate, explicit opt-in; see [Package Installation](#package-installation)
below.

### Minimal
Essential configs only - perfect for servers or minimal setups:
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
- 1Password CLI (`op`) configuration
- macOS-specific: Karabiner, Kitty terminal configuration

### All
- `--profile all` symlinks every component declared in `manifest.conf`,
  regardless of its `profiles` list

Valid profiles are `minimal | standard | full | all`.

## Package Installation

Packages are **never** installed by a plain `./bootstrap.sh` run. Pass
`--install-packages` to opt in:

```bash
# Install packages at the tier matching the active --profile (default: minimal)
./bootstrap.sh --install-packages

# Install packages at a tier different from the link profile
./bootstrap.sh --profile minimal --install-packages --packages full
```

The package **tier** (`minimal | standard | full`) defaults to the link
`profile` (`all` maps to `full`) and can be overridden independently with
`--packages <tier>`. `--packages` without `--install-packages` is an error.

Package tiers are declared in [`packages.conf`](packages.conf),
the single source of truth read by `install/packages.sh`:

- **minimal**: `git`, `git-lfs`, `curl`, `wget`, `zsh`, `tmux`
- **standard**: everything in minimal, plus core dev tooling — build tools,
  `ripgrep`, `fd`, `fzf`, `jq`, `tree`, `bat`, `htop`, `python`, `node`,
  `neovim`, `eza`, `uv`, and related GNU/CLI utilities
- **full**: everything in standard, plus language toolchains (Rust, Go, Ruby,
  Java, Perl, `pyenv`, `cmake`, `llvm`, ...), networking/security tools, and
  (macOS only) GUI casks such as 1Password, Kitty, Docker, and Brave

Some entries are single-platform, so a tier is not installed identically on
both OSes: `node` and the GNU userland (`coreutils`, `findutils`, `gnu-sed`,
`grep`) are macOS-only via `brew`, while `thefuck` is Ubuntu-only.

**macOS**: `--install-packages` installs Homebrew (if missing), links
`~/.config/homebrew/brew.env` from this repo *before* running `brew bundle`
(so environment settings apply to the install), then generates a Brewfile
from the selected tier and runs `brew bundle` against it.

**Ubuntu**: `--install-packages` first does a single atomic
`apt-get install` of the tier's required packages (a failure here aborts, as
system state is not yet mutated further). It then attempts optional,
network-dependent extras — Neovim (official archive), `eza` (HTTPS apt repo),
`uv`, and `thefuck` — each retried on failure; failures there are summarized
at the end without aborting the rest of the install.

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
├── install/               # OS-specific installation scripts
│   ├── install-macos.sh   # macOS setup
│   ├── install-ubuntu.sh  # Ubuntu setup
│   ├── manifest.sh        # Manifest reader used by bootstrap.sh and dotfiles
│   └── packages.sh        # Package tier reader used by --install-packages
├── Makefile               # install/update/validate targets
├── bootstrap.sh           # Main installation script
├── manifest.conf          # Declarative link manifest, grouped by profile section
└── packages.conf          # Declarative package tiers, grouped by tier section
```

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
- LSP support; languages enabled in `languages.lua` (Lua, Terraform, C++ by
  default) with more available on demand
- Modular plugin organization
- Custom keybindings and workflows
- AI integration via `claude-code.nvim`

### Git
- Global gitignore patterns
- Sensible defaults
- Aliases for common operations

### Tmux
- Deliberately minimal: mouse support, fast escape, and correct
  terminfo/truecolor (`tmux-256color` + `Tc` overrides)

## Platform-Specific Features

### macOS
- Homebrew package management, tiered by `--packages` (`--install-packages`)
- `brew.env` linked to `~/.config/homebrew/brew.env` before every Homebrew run
- System defaults configuration (`--apply-macos-defaults`)
- Security hardening (`--harden`)
- Karabiner for keyboard customization
- Kitty terminal configuration

### Ubuntu
- Required apt packages installed atomically, tiered by `--packages`
  (`--install-packages`)
- Optional network extras (Neovim, eza, uv, thefuck) retried and reported
  without aborting the rest of the install
- Compatibility aliases (fd, bat)

## Manual Steps

After installation, some manual steps may be required:

### Set Zsh as Default Shell
```bash
# Ubuntu/Debian
chsh -s $(which zsh)

# Then logout and login again
```

### Machine-local Git identity

Git identity and signing live in an untracked, machine-local file that the main
config includes. `*.local` files are intentionally not symlinked, so create it
once per machine:

```bash
cp config/git/gitconfig.local.example ~/.config/git/gitconfig.local
# then edit it and set [user] name / email (and optional signing)
```

The example documents optional delta-pager and SSH-signing blocks. Nothing in
`gitconfig.local` is committed.

### Install Language-Specific Tools
```bash
# Go
go install golang.org/x/tools/gopls@latest

# Python provider for Neovim (pynvim). This virtualenv setup is idempotent:
NVIM_VENV="${XDG_DATA_HOME:-$HOME/.local/share}/nvim/nvim-venv"
uv venv --allow-existing "$NVIM_VENV"
uv pip install --python "$NVIM_VENV/bin/python" --upgrade pynvim

# Rust
rustup component add rust-analyzer
```

For a local provider verification, run the setup commands above once, start
Neovim normally, and confirm `:checkhealth provider` is successful.

### Reproducible plugin recovery
After syncing this configuration on a new or repaired machine, open Neovim and
run `:Lazy restore`. It installs the revisions in `config/nvim/lazy-lock.json`.

### Intentional updates
Update plugins only when you intend to review a dependency change: run
`:Lazy update`, inspect `config/nvim/lazy-lock.json`, verify Neovim starts
cleanly, and commit the lockfile with the related configuration change. Update the pinned
lazy.nvim bootstrap revision in `lazy.lua` in the same change when upgrading
the manager.

Mason tools are deliberately not version-pinned. Run `:MasonUpdate` and update
or install a needed tool only when you choose to do so; verify the affected
language locally. CI does not install or update Mason tools.

## Updating

To update configurations:
```bash
cd ~/.dotfiles
make update
# or: git pull --ff-only && dotfiles sync
```

`dotfiles sync` uses the stored profile. To change it, run
`dotfiles profile standard` (or `minimal`, `full`, or `all`) and then sync.

The repository location is not hardcoded: `DOTDIR` is derived from the physical
target of the linked `dotfiles` CLI, falling back to `~/.dotfiles`. Cloning
elsewhere works as long as you re-link from that location.

## Enabling auto-sync hooks (optional)

Git hooks can re-sync your symlinks automatically after you pull or switch
branches. They are opt-in — a fresh clone does not enable them. To turn them on:

```bash
bash .githooks/setup.sh   # sets: git config core.hooksPath .githooks
```

- `post-merge` runs after `git pull`, `post-checkout` after switching branches.
- Each runs `dotfiles sync` only when the change touched `config/`, `install/`,
  `bin/`, or `bootstrap.sh` — and always against your **stored profile**, so
  only that profile's links are reconciled (`post-checkout` syncs in the
  background, logging to `~/.cache/dotfiles-sync.log`).
- Disable at any time: `git config --unset core.hooksPath`.

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

### Adding a Component
Components are declared in `manifest.conf`, the single source of
truth for name/kind/src/dest/platforms, grouped into cumulative profile
sections (`[minimal]` ⊂ `[standard]` ⊂ `[full]`). `bootstrap.sh` link,
`dotfiles status`, and `dotfiles uninstall` all derive their file set from it.

1. Add configuration files to `config/<tool-name>/`
2. Add a matching line under the right profile section in
   `manifest.conf` (`name kind src dest [platforms]`)
3. Document any special requirements

## Contributing

This is a personal configuration, but feel free to fork and adapt for your own use.

## License

MIT - See LICENSE file for details.
