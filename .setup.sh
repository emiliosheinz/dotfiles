# Install Brew
# Docs: https://brew.sh/index_pt-br
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# # Install nvm
brew install nvm 
mkdir "$HOME/.nvm"
export NVM_DIR=$HOME/.nvm;
source $NVM_DIR/nvm.sh;

# Install node
nvm install --lts
nvm use --lts
nvm alias default node

# Install oh-my-zsh
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"

# Install VSCode
brew install --cask visual-studio-code

# Install Fig
brew install fig
