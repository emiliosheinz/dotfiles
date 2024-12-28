#!/bin/bash
set -e
set -x

# MacOS
xcode-select --install 

# Homebrew
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" 
export PATH=/opt/homebrew/bin:$PATH

# Stow
brew install stow 

# Utilities
brew install fzf
stow bin
stow git

# iTerm2
brew install --cask iterm2 
stow itemr2 

# ZSH
sh -c "$(curl -fsSL https://install.ohmyz.sh/)" 
stow zsh 

# nvim
brew install neovim
stow nvim

# tmux
brew install tmux
stow tmux

# Node
brew install nvm 
mkdir $HOME/.nvm 

nvm install --lts 
nvm use --lts 
nvm alias default node 

# GitHub
brew install gh

# Apps
brew install --cask 1password
brew install --cask google-chrome
brew install --cask spotify
brew install --cask raycast
brew install --cask docker
brew install --cask aldente
brew install --cask rectangle

# Fonts 
brew install --cask font-fira-code-nerd-font
