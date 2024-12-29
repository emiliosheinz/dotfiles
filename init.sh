#!/bin/bash
set -e

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

git clone --recurse-submodules https://github.com/emiliosheinz/dotfiles.git $HOME/dotfiles

echo ""
echo "Dotfiles repository cloned to $HOME/dotfiles"
echo "Please, execute the following commands to continue the installation:"
echo "cd $HOME/dotfiles && ./bootstrap.sh"
