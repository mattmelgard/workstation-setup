#!/usr/bin/env bash

set -eo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

echo ">> Beginning setup process"

# Install Brew if it's not already available on the system
if [[ $(command -v brew) == "" ]]; then
    echo ">> Installing Brew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    # Make brew available on the path
    eval "$(/opt/homebrew/bin/brew shellenv)"
else
    echo ">> Brew is already installed on the system. Continuing with setup..."
fi

export HOMEBREW_NO_AUTO_UPDATE=1

# Install 1Password CLI tool and login with it
if [[ $(command -v op) == "" ]]; then
    echo ">> Installing the 1Password CLI tool..."
    brew install 1password-cli
else
    echo ">> 1password CLI tool (op) is already installed on the system. Continuing with setup..."
fi
echo ">> Logging you in to 1Password. You may need to enter your login credentials below..."
eval $(op signin)

# Clone my private dotfiles repo
PERSONAL_REPOS_DIR="$HOME/personal"
DOTFILES_REPO_PATH="$PERSONAL_REPOS_DIR/dotfiles"
if [ ! -d "$DOTFILES_REPO_PATH" ]; then
    echo ">> Grabbing Github SSH key..."
    ssh-add - <<< $(op read 'op://SSH Keys/Github SSH Key/private key')
    echo ">> Cloning dotfiles repo..."
    mkdir -p "$PERSONAL_REPOS_DIR"
    git clone giqt@github.com:mattusaur/dotfiles.git "$DOTFILES_REPO_PATH"
else
    echo ">> Dotfiles repo already found at $DOTFILES_REPO_PATH. Continuing with setup..."
fi

echo ">> Installing brew packages from the dotfiles Brewfile..."
# NOTE: Ignores existing applications rather than overwrite them.
brew bundle --file "$DOTFILES_REPO_PATH/Brewfile" || true

if [ ! -f "$HOME/.gitconfig" ]; then
    echo ">> Configuring Git using dotfiles..."
    cp "$DOTFILES_REPO_PATH/.gitconfig" "$HOME/"
else
    echo ">> .gitconfig file already found... Continuing with setup..."
fi

1PASSWORD_SSH_AGENT_CONFIG_DIR="$HOME/.config/1Password/ssh"
if [ ! -d "$1PASSWORD_SSH_AGENT_CONFIG_DIR" ]
    echo ">> Configuring the SSH Agent with 1Password SSH Keys using dotfiles..."
    cp "$DOTFILES_REPO_PATH/ssh/config" "$HOME/.ssh/config"
    mkdir -p "$1PASSWORD_SSH_AGENT_CONFIG_DIR"
    cp "$DOTFILES_REPO_PATH/.config/1Password/ssh/agent.toml" "$1PASSWORD_SSH_AGENT_CONFIG_DIR"
else
    echo ">> 1Password SSH agent appears to already be configured. Continuing with setup..."
fi

echo ">> Configuring OhMyZsh and PowerLevel10k using dotfiles..."
if [ ! -d "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k" ]; then
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
    git clone \
        --depth=1 https://github.com/romkatv/powerlevel10k.git \
        "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k"
fi

if [ ! -f "$HOME/.p10k.zsh" ]; then
    cp "$DOTFILES_REPO_PATH/.p10k.zsh" "$HOME/"
fi

if [ ! -f "$HOME/.vimrc" ]; then
    echo ">> Configuring OhMyZsh and PowerLevel10k using dotfiles..."
    cp "$DOTFILES_REPO_PATH/.vimrc" "$HOME/"
else
    echo ">> A Vim config file was already found... Continuing..."
fi

if [ ! -f "$HOME/.zshrc" ]; then
    echo ">> Configuring zsh using dotfiles..."
    cp "$DOTFILES_REPO_PATH/.zshrc" "$HOME/"
    cp "$DOTFILES_REPO_PATH/.zprofile" "$HOME/"
    cp "$DOTFILES_REPO_PATH/.zlogin" "$HOME/"
else
    echo ">> Zsh appears to already be configured... Continuing with setup..."
fi

echo ">> Initial setup is complete, but some manual steps are still required:"
echo ">> First, login with the 1Password desktop application using the credentials below:"
op item get '1Password Account Login' --fields 'label=email,label=account-key,label=password' | tr ',' '\n'
echo ">> Additionally you'll need to install required fonts for PowerLevel10k by opening iterm2 and running p10k"
