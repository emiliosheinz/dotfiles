#!/bin/bash
set -e

wait_for_confirmation ()
{
  echo "Press any key to continue"
  read -n 1
}

# Homebrew
echo "📦 Installing Homebrew"
wait_for_confirmation
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" 
eval "$(/opt/homebrew/bin/brew shellenv)"

# Stow
echo "📦 Installing Stow"
wait_for_confirmation
brew install stow 

# Create config symlinks
echo "📦 Creating config symlinks"
wait_for_confirmation
stow git
stow bin
stow zsh 
stow iterm2 
stow nvim
stow tmux

# Utilities
echo "📦 Installing Utilities"
wait_for_confirmation
brew install fzf
brew install lazygit
brew install gnupg
brew install ripgrep

# iTerm2
echo "📦 Installing iTerm2"
wait_for_confirmation
brew install --cask iterm2 

# ZSH
echo "📦 Installing Oh My Zsh"
wait_for_confirmation
sh -c "$(curl -fsSL https://install.ohmyz.sh/)" "" --unattended --keep-zshrc

# nvim
echo "📦 Installing Neovim"
wait_for_confirmation
brew install neovim

# tmux
echo "📦 Installing Tmux"
wait_for_confirmation
brew install tmux
git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm

# Node
echo "📦 Installing Node"
wait_for_confirmation
brew install nvm 
mkdir $HOME/.nvm 

source $(brew --prefix nvm)/nvm.sh

nvm install --lts 
nvm use --lts 
nvm alias default node 

# Apps
echo "📦 Installing Apps"
wait_for_confirmation
brew install --cask 1password
brew install --cask google-chrome
brew install --cask spotify
brew install --cask raycast
brew install --cask docker
brew install --cask aldente
brew install --cask rectangle

# Fonts 
echo "📦 Installing Fonts"
wait_for_confirmation
brew install --cask font-fira-code-nerd-font

# Setup GPG keys
echo "🔑 Setting up GPG keys"
wait_for_confirmation
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
wait_for_confirmation
defaults write -g com.apple.swipescrolldirection -boolean NO 
echo "🔧 Setting trackpad and mouse scaling"
wait_for_confirmation
defaults write -g com.apple.trackpad.scaling 2
defaults write -g com.apple.mouse.scaling 1
echo "🔧 Setting key repeat and delay for improved nvim experience"
wait_for_confirmation
defaults write NSGlobalDomain ApplePressAndHoldEnabled -bool false
defaults write NSGlobalDomain KeyRepeat -int 2
defaults write NSGlobalDomain InitialKeyRepeat -int 15
echo "🔧 Setting dock preferences"
wait_for_confirmation
defaults write com.apple.dock autohide -int 1
defaults write com.apple.dock autohide-time-modifier -int 1
defaults write com.apple.dock tilesize -int 40
defaults write com.apple.dock show-recents -int 0
defaults write com.apple.dock largesize 35
killall Dock

# Desktop background
echo "🔧 Setting desktop background to black"
wait_for_confirmation
osascript -e 'tell application "System Events" to set picture of every desktop to "/System/Library/Desktop Pictures/Solid Colors/Black.png"'

echo "🔑 Setup 1Password and press enter when done"
open -a "1Password"
wait_for_confirmation

echo "🌐 Setup Google Chrome and press enter when done"
open -a "Google Chrome"
wait_for_confirmation

echo "🎵 Setup Spotify and press enter when done"
open -a "Spotify"
wait_for_confirmation

echo "🚀 Setup Raycast and press enter when done"
echo "1. Go to Settings > Keyboard > Keyboard Shortcuts > Spotlight and turn off 'Show Spotlight search'"
echo "2. Login to your account"
echo "3. Check 'Launch Raycast at login'"
echo "4. Change 'Raycast Hotkey' to ⌘ + Space"
open -a "Raycast"
wait_for_confirmation

echo "🐳 Setup Docker and press enter when done"
open -a "Docker"
wait_for_confirmation

echo "🔧 Setting up Rectangle shortcuts"
echo "1. Give it the necessary permissions"
echo "2. Import the configuration file from ~/dotfiles/rectangle/config.json"
open -a "Rectangle"
wait_for_confirmation

echo "🍝 Setting up AlDente"
echo "1. Enable 'Launch at login'"
echo "2. Change limit to 75%"
open -a "Al Dente"
wait_for_confirmation

echo "💻 Setting up iTerm"
echo "1. Go to Settings > settings and check 'Load preferences from a custom folder or URL'"
echo "2. Set the folder to ~/config/iterm2/settings"
echo "3. Set Save changes to 'Automatically'" 
wait_for_confirmation
