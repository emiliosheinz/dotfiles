#!/bin/bash
set -e

# Make sure XCode Command Line Tools are installed and up to date
if xcode-select -p &>/dev/null; then
  echo "✅ XCode Command Line Tools are already installed"
  echo "🔄 Checking for updates to XCode Command Line Tools"
  if softwareupdate --list | grep -q "Command Line Tools"; then
    echo "🔄 Updating XCode Command Line Tools"
    sudo softwareupdate --install -a
  else
    echo "✅ XCode Command Line Tools are up to date"
  fi
else
  echo "📦 Installing MacOS XCode Command Line Tools"
  xcode-select --install
  echo "Complete the installation of XCode Command Line Tools before proceeding"
  echo "Press enter to continue"
  read
fi

# Configure GitHub's SSH key
if [ -f "$HOME/.ssh/id_ed25519" ]; then
  echo "✅ SSH key already exists"
else
  echo "🔑 Generating SSH key"
  echo "Enter your email address:"
  read email
  ssh-keygen -t ed25519 -C "$email"
  eval "$(ssh-agent -s)"

  echo "📝 Creating SSH config"
  touch $HOME/.ssh/config
  echo "Host github.com" >> $HOME/.ssh/config
  echo "  AddKeysToAgent yes" >> $HOME/.ssh/config
  echo "  UseKeychain yes" >> $HOME/.ssh/config
  echo "  IdentityFile ~/.ssh/id_ed25519" >> $HOME/.ssh/config

  ssh-add --apple-use-keychain ~/.ssh/id_ed25519

  pbcopy < $HOME/.ssh/id_ed25519.pub
  echo "📋 SSH key copied to clipboard, paste it in GitHub"

  open https://github.com/settings/ssh/new

  echo "Press enter to continue"
  read
fi

git clone --recurse-submodules git@github.com:emiliosheinz/dotfiles.git $HOME/dotfiles

echo ""
echo "Dotfiles repository cloned to $HOME/dotfiles"
echo "The following command was copied to your clipboard. Paste it in your terminal to continue:"
echo ""
command="cd $HOME/dotfiles && ./install.sh"
echo $command | pbcopy
echo $command
