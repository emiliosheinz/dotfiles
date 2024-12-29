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

# Node
echo "📦 Installing Node"
brew install nvm 
mkdir $HOME/.nvm 

nvm install --lts 
nvm use --lts 
nvm alias default node 

# GitHub
brew install gh

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
