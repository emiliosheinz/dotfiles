#!/bin/bash
set -e

# MacOS
echo "📦 Installing MacOS XCode Command Line Tools"
xcode-select --install 

echo "Complete the installation of Xcode Command Line Tools before proceeding"
echo "Press enter to continue"
read

git clone --recurse-submodules git@github.com:emiliosheinz/dotfiles.git $HOME/dotfiles

echo ""
echo "Dotfiles repository cloned to $HOME/dotfiles"
echo "Please, execute the following commands to continue the installation:"
echo "cd $HOME/dotfiles && ./bootstrap.sh"
