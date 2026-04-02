#!/bin/bash
set -e

wait_for_confirmation ()
{
  echo "Press any key to continue"
  read -n 1
}

BREW_PREFIX="${BREW_PREFIX:-$HOME/.homebrew}"

setup_homebrew() {
  if command -v brew &> /dev/null; then
    echo "✅ Homebrew already installed at $(brew --prefix)"
  else
    echo "📦 Installing Homebrew to $BREW_PREFIX"
    git clone https://github.com/Homebrew/brew "$BREW_PREFIX"
  fi
  eval "$("$BREW_PREFIX/bin/brew" shellenv)"
}

setup_homebrew

# Stow
echo "📦 Installing Stow"
wait_for_confirmation
brew install stow 

# Create config symlinks
echo "📦 Creating config symlinks"
wait_for_confirmation
stow git
stow scripts
stow zsh 
stow nvim
stow tmux
stow opencode
stow claude
stow karabiner
stow btop
stow macos
stow ccstatusline

# Utilities
echo "📦 Installing Utilities"
wait_for_confirmation
brew install fzf
brew install lazygit
brew install gnupg
brew install ripgrep
brew install jq
brew install gh

# Modern CLI replacements
echo "📦 Installing Modern CLI Tools"
wait_for_confirmation
brew install eza
brew install bat
brew install zoxide
brew install btop

# Other CLI tools
echo "📦 Installing Other CLI Tools"
wait_for_confirmation
brew install --cask gcloud-cli

echo "🎨 Configuring bat theme"
if command -v bat &> /dev/null; then
  mkdir -p "$(bat --config-dir)/themes"
  if curl -fsSL https://github.com/catppuccin/bat/raw/main/themes/Catppuccin%20Mocha.tmTheme -o "$(bat --config-dir)/themes/Catppuccin-mocha.tmTheme"; then
    bat cache --build
    echo "✅ bat theme configured"
  else
    echo "⚠️  Failed to download bat theme, using default"
  fi
else
  echo "⚠️  bat not found, skipping theme configuration"
fi

echo "🎨 Configuring btop theme"
if command -v btop &> /dev/null; then
  mkdir -p ~/.config/btop/themes
  if curl -fsSL https://github.com/catppuccin/btop/raw/main/themes/catppuccin_mocha.theme -o ~/.config/btop/themes/catppuccin_mocha.theme; then
    echo "✅ btop theme configured"
  else
    echo "⚠️  Failed to download btop theme, using default"
  fi
else
  echo "⚠️  btop not found, skipping theme configuration"
fi

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
~/.tmux/plugins/tpm/bin/install_plugins

# Node
echo "📦 Installing Node"
wait_for_confirmation
curl https://get.volta.sh | bash
volta install node
volta install corepack

# Rosetta (required for Docker on Apple Silicon)
if [[ $(uname -m) == "arm64" ]]; then
  echo "📦 Installing Rosetta 2 (required for Docker)"
  wait_for_confirmation
  softwareupdate --install-rosetta --agree-to-license
fi

# Docker
echo "📦 Installing Docker"
wait_for_confirmation
brew install --cask docker
brew install jesseduffield/lazydocker/lazydocker

# Install AI related tools
echo "📦 Installing AI Tools"
wait_for_confirmation
brew install anomalyco/tap/opencode
curl -fsSL https://claude.ai/install.sh | bash
npx get-shit-done-cc@latest --global --opencode --claude

# Apps
echo "📦 Installing Apps"
wait_for_confirmation
brew install --cask 1password
brew install --cask google-chrome
brew install --cask spotify
brew install --cask raycast
brew install --cask aldente
brew install --cask rectangle
brew install --cask karabiner-elements
brew install --cask displaylink
brew install --cask shottr
brew install --cask twist
brew install --cask roam

# Fonts 
echo "📦 Installing Fonts"
wait_for_confirmation
brew install --cask font-fira-code-nerd-font

# Apply macOS system defaults
echo "🔧 Applying macOS system defaults"
wait_for_confirmation
if [ -f ~/.macos ]; then
  chmod +x ~/.macos
  ~/.macos
else
  echo "⚠️  .macos script not found, skipping system defaults"
fi

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
echo "1. Change 'Raycast Hotkey' to ⌘ + Space"
echo "2. Check 'Open at login'"
echo "3. Check 'Use Raycast Emoji Picker'"
echo "4. Grant access to Files and Folders"
echo "5. Login to your account"
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
open -a "AlDente"
wait_for_confirmation

echo "💻 Setting up iTerm"
echo "1. Go to Settings > General > Settings"
echo "2. Click Import All Settings and Data"
echo "3. Import the settings and data from ~/dotfiles/iterm2/config.itermexport" 
open -a "iTerm"
wait_for_confirmation

echo "⌨️  Setting up Karabiner-Elements"
echo "1. Grant necessary permissions when prompted"
echo "2. Configuration is already symlinked"
open -a "Karabiner-Elements"
wait_for_confirmation

echo "📸 Setting up Shottr"
echo "1. Grant necessary permissions when prompted"
echo "2. Enable 'Launch at login'"
echo "3. Set Screenshots folder as $HOME/Pictures/Screenshots"
open -a "Shottr"
wait_for_confirmation

echo "💬 Setting up Twist"
echo "1. Login to your account"
echo "2. Enable 'Launch at login'"
open -a "Twist"
wait_for_confirmation

echo "🏢 Setting up Roam"
echo "1. Login to your account"
open -a "Roam"
wait_for_confirmation

echo "🔧 Setting up GitHub CLI"
echo "1. Run 'gh auth login' to authenticate"
echo "2. Follow the prompts to authenticate with GitHub"
wait_for_confirmation

echo "🧶 Setting up npm"
echo "1. Run 'yarn npm login' to authenticate"
echo "2. Follow the prompts to authenticate with npm"
wait_for_confirmation

echo "📱 Setting up gcloud CLI"
echo "1. Run 'gcloud auth login' to authenticate"
echo "2. Follow the prompts to authenticate with your Google account"
echo "3. Run 'gcloud auth configure-docker europe-west2-docker.pkg.dev --project=circuit-api-284012' to configure Docker authentication for Google Artifact Registry"
wait_for_confirmation

echo "🎉 Setup complete! Enjoy your new development environment!"
