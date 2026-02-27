# Set PATH, MANPATH, etc., for Homebrew.
eval "$("$HOME/.homebrew/bin/brew" shellenv)"

# History size
export HISTFILESIZE=100000
export HISTSIZE=100000

# NVM
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
