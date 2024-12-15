# Install Brew
# Docs: https://brew.sh/index_pt-br
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
echo '# Set PATH, MANPATH, etc., for Homebrew.' >> $HOME/.zprofile
echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> $HOME/.zprofile
eval "$(/opt/homebrew/bin/brew shellenv)"

# # Install nvm
brew install nvm 
mkdir $HOME/.nvm
export NVM_DIR=$HOME/.nvm;
source $NVM_DIR/nvm.sh;

# Install node
nvm install --lts
nvm use --lts
nvm alias default node

# Install oh-my-zsh
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
git clone https://github.com/spaceship-prompt/spaceship-prompt.git "$ZSH_CUSTOM/themes/spaceship-prompt" --depth=1
ln -s "$ZSH_CUSTOM/themes/spaceship-prompt/spaceship.zsh-theme" "$ZSH_CUSTOM/themes/spaceship.zsh-theme"

# Install VSCode
brew install --cask visual-studio-code

# Install Fig
brew install fig

# Install GitHub CLI
brew install gh

# Install Fira Code
brew tap homebrew/cask-fonts
brew install --cask font-fira-code
