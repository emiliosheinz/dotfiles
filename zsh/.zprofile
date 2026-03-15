# Set PATH, MANPATH, etc., for Homebrew.
eval "$("$HOME/.homebrew/bin/brew" shellenv)"
export PATH="$(brew --prefix)/share/google-cloud-sdk/bin:$PATH"

# History size
export HISTFILESIZE=100000
export HISTSIZE=100000
