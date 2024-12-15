# Install MacOS development tools
xcode-select --install

# Install Homebrew
# Docs: https://brew.sh
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Install nvm
brew install nvm 
mkdir $HOME/.nvm
export NVM_DIR=$HOME/.nvm;
source $NVM_DIR/nvm.sh;

# Install node
nvm install --lts
nvm use --lts
nvm alias default node

# Install oh-my-zsh
sh -c "$(curl -fsSL https://install.ohmyz.sh/)"

# Install GitHub CLI
brew install gh

# Install Fira Code
brew tap homebrew/cask-fonts
brew install --cask font-fira-code
