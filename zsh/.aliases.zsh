#!/usr/bin/env zsh

# eza - modern ls replacement
if command -v eza &> /dev/null; then
  alias ls='eza --icons --group-directories-first'
  alias ll='eza --icons --group-directories-first -l'
  alias la='eza --icons --group-directories-first -la'
  alias lt='eza --icons --group-directories-first --tree --level=2'
  alias lta='eza --icons --group-directories-first --tree --level=2 -a'
  alias lg='eza --icons --group-directories-first -l --git'
  alias lga='eza --icons --group-directories-first -la --git'
fi

# bat - syntax-highlighted cat with git integration
if command -v bat &> /dev/null; then
  alias cat='bat --style=plain --paging=never'
  alias catt='bat --style=full'
  alias bathelp='bat --plain --language=help'
  
  export MANPAGER="sh -c 'col -bx | bat -l man -p'"
  export MANROFFOPT="-c"
  export BAT_THEME="Catppuccin Mocha"
  
  help() {
    "$@" --help 2>&1 | bathelp
  }
fi

# btop - system monitor
if command -v btop &> /dev/null; then
  alias top='btop'
  alias htop='btop'
fi
