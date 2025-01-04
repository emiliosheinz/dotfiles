#!/bin/bash
set -e

# Homebrew
echo "📦 Installing Homebrew"
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" 
eval "$(/opt/homebrew/bin/brew shellenv)"

# Stow
echo "📦 Installing Stow"
brew install stow 

# Create config symlinks
echo "📦 Creating config symlinks"
stow git
stow bin
stow zsh 
stow iterm2 
stow nvim
stow tmux

# Utilities
echo "📦 Installing Utilities"
brew install fzf
brew install lazygit
brew install gnupg
brew install ripgrep

# iTerm2
echo "📦 Installing iTerm2"
brew install --cask iterm2 

# ZSH
echo "📦 Installing Oh My Zsh"
sh -c "$(curl -fsSL https://install.ohmyz.sh/)" "" --unattended --keep-zshrc

# nvim
echo "📦 Installing Neovim"
brew install neovim

# tmux
echo "📦 Installing Tmux"
brew install tmux
git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm

# Node
echo "📦 Installing Node"
brew install nvm 
mkdir $HOME/.nvm 

source $(brew --prefix nvm)/nvm.sh

nvm install --lts 
nvm use --lts 
nvm alias default node 

# Apps
echo "📦 Installing Apps"
brew install --cask 1password
brew install --cask google-chrome
brew install --cask spotify
brew install --cask raycast
brew install --cask docker
brew install --cask aldente
brew install --cask rectangle

# Fonts 
echo "📦 Installing Fonts"
brew install --cask font-fira-code-nerd-font

# Setup GPG keys
echo "🔑 Setting up GPG keys"
echo "Read more about the setup here: https://docs.github.com/pt/authentication/managing-commit-signature-verification/generating-a-new-gpg-key"
gpg --full-generate-key
gpg --list-secret-keys --keyid-format=long
echo "Copy the key ID and paste it here:"
read key_id
gpg --armor --export $key_id | pbcopy
echo "📋 GPG key copied to clipboard, paste it in GitHub"
open https://github.com/settings/gpg/new

# Gesture and keyboard settings
echo "🔧 Disabling natural scroll direction"
defaults write -g com.apple.swipescrolldirection -boolean NO 
echo "🔧 Setting trackpad and mouse scaling"
defaults write -g com.apple.trackpad.scaling 2
defaults write -g com.apple.mouse.scaling 1
echo "🔧 Setting key repeat and delay for improved nvim experience"
defaults write NSGlobalDomain ApplePressAndHoldEnabled -bool false
defaults write NSGlobalDomain KeyRepeat -int 2
defaults write NSGlobalDomain InitialKeyRepeat -int 15

defaults write com.apple.dock autohide -int 1
defaults write com.apple.dock autohide-time-modifier -int 1
defaults write com.apple.dock tilesize -int 35
defaults write com.apple.dock show-recents -int 0
defaults write com.apple.dock largesize 35
killall Dock

# Set desktop background
# Signin to 1Password
# Signin to google chrome
# Signin to spotify
# Signin to raycast
# Signin to docker
# Set up rectangle shortcuts
# Set up al dente
# Set up gpg keys
# Modularize everything so that it can be run in parts
