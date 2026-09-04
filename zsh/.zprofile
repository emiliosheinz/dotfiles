# Set PATH, MANPATH, etc., for Homebrew.
eval "$("$HOME/.homebrew/bin/brew" shellenv)"
export PATH="$(brew --prefix)/share/google-cloud-sdk/bin:$PATH"

# Homebrew links only the versioned python names into bin. libexec/bin carries
# the unversioned `python` and `pip` that build scripts and agents reach for.
[ -d "$HOMEBREW_PREFIX/opt/python@3/libexec/bin" ] &&
    export PATH="$HOMEBREW_PREFIX/opt/python@3/libexec/bin:$PATH"
