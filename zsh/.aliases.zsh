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

# ws wrapper — propagates worktrunk's cd/exec directives to the caller shell.
# Mirrors the pattern from `wt config shell init zsh`: pre-create temp files,
# export the directive env vars, run the command, then apply cd/source here.
# Without this wrapper, `ws wt switch` would invoke the wt binary as a
# grandchild process and the directory change would be lost when it exits.
ws() {
  local cd_file exec_file exit_code=0
  cd_file="$(mktemp)"
  exec_file="$(mktemp)"
  WORKTRUNK_DIRECTIVE_CD_FILE="$cd_file" \
    WORKTRUNK_DIRECTIVE_EXEC_FILE="$exec_file" \
    command tmux-workspace-manager "$@" || exit_code=$?
  if [[ -s "$cd_file" ]]; then
    builtin cd -- "$(<"$cd_file")"
    local cd_exit=$?
    [[ $exit_code -eq 0 ]] && exit_code=$cd_exit
  fi
  if [[ -s "$exec_file" ]]; then
    source "$exec_file"
    local src_exit=$?
    [[ $exit_code -eq 0 ]] && exit_code=$src_exit
  fi
  rm -f "$cd_file" "$exec_file"
  return $exit_code
}

# Sandboxed agents — run claude and opencode under sandbox-exec.
# Uses ~/dotfiles/sandbox/agents.sb via the sandbox-run wrapper.
# Workdirs under ~/dev/ and ~/dotfiles/ need no extra config; all other
# paths get ancestor literals injected automatically at launch time.
if [[ -x "${HOME}/.local/scripts/sandbox-run" ]]; then
  function claude() {
    sandbox-run claude --dangerously-skip-permissions "$@"
  }
  function opencode() {
    OPENCODE_PERMISSION='{"*":"allow"}' sandbox-run opencode "$@"
  }
fi
