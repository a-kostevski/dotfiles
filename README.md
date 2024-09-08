# Dotfiles
Repository of personal dotfiles. 

## Table of Contents

- [Installation](#installation)

- [Scripts](#scripts)
- [License](#license)

## Installation

   ```zsh
   git clone https://github.com/yourusername/dotfiles.git 
   cd dotfiles
   ./bootstrap.sh
   ```
Options
| Flag | Details | Default |
| ---- | ------- |-------- |
| -c --config-dest | $HOME/.config | Destination of dotfiles in cofig | 
| -b --bin-dest | $HOME/.local/bin | Destination of scripts in bin |
| -d --dry-run | false | Don't symlink files, just print commands |

## Tools
Todo

## MacOS configuration
Todo

## Scripts

The `bin/` directory contains various scripts for automating tasks:
- **mac_clock_toggle**: Toggle analog clock
- **mk_license**: Generate GNU or MIT license.
- **mkx**: Create executable file


More details about each script can be found in the `bin/` directory.

## License

This repository is licensed under the MIT License. See the [LICENSE](LICENSE) file for more details.

---
