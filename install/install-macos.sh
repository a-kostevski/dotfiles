dot_title "Installing macOS"

HOME=${HOME:-$(echo "/Users/$(whoami)")}

dot_mkdir $HOME/dev
dot_mkdir $HOME/dev/projects
dot_mkdir $HOME/dev/scripts
dot_mkdir $HOME/.cache
dot_mkdir $HOME/.config
dot_mkdir $HOME/.local
dot_mkdir $HOME/.local/bin
dot_mkdir $HOME/.local/share
dot_mkdir $HOME/.local/state
dot_mkdir $HOME/pictures/mac-screenshots

dot_header "Checking for command line tools"
check_install "$(xcode-select --version)" "xcode-select --install"

dot_header "Checking for Rosetta 2"
check_install "/Library/Apple/usr/share/rosetta/rosetta" "sudo softwareupdate --install-rosetta --agree-to-license"

dot_header "Checking for Homebrew"
if [[ $(uname -m) == "arm64" ]]; then
    brew_prefix="/opt/homebrew"
else
    brew_prefix="/usr/local"
fi

check_install "$brew_prefix/bin/brew" "/bin/bash -c \"$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""

eval "$(brew_prefix/bin/brew shellenv)"
unset brew_prefix

dot_header "Checking for zsh"
target_shell=$HOMEBREW_PREFIX/bin/zsh
check_install $target_shell "brew install zsh"

dot_header "Checking for Homebrew zsh as default shell"
current_shell=$(dscl . -read /Users/$USER UserShell | awk '{print $2}')
if [[ $current_shell != $target_shell ]]; then
    dot_info "Changing default shell to Homebrew zsh"
    # Appends the new shell to the list of allowed shells
    if ! grep -q $target_shell /private/etc/shells; then
        dot_info "Adding $target_shell to /private/etc/shells"
        echo $target_shell | sudo tee -a /private/etc/shells
    fi
    chsh -s $target_shell
    dot_success "Changed default shell to Homebrew zsh"
else
    dot_info "Default shell is already Homebrew zsh"
fi

export HOMEBREW_NO_ANALYTICS=1
export HOMEBREW_NO_INSECURE_REDIRECT=1
dot_header "Installing Homebrew packages"
brew bundle --file=$dot_root/config/homebrew/Brewfile-min --no-upgrade
dot_success "Installed Homebrew packages"

