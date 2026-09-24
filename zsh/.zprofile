# Set PATH, MANPATH, etc., for Homebrew.
eval "$("$HOME/.homebrew/bin/brew" shellenv)"

# Homebrew links only the versioned python names into bin. libexec/bin carries
# the unversioned `python` and `pip` that build scripts and agents reach for.
[ -d "$HOMEBREW_PREFIX/opt/python@3/libexec/bin" ] &&
    export PATH="$HOMEBREW_PREFIX/opt/python@3/libexec/bin:$PATH"

# NVM
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
