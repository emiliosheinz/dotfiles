#!/usr/bin/env bash
# Claude Code status line — inspired by Spaceship Prompt style
input=$(cat)

cwd=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // ""')
model=$(echo "$input" | jq -r '.model.display_name // ""')
used=$(echo "$input" | jq -r '.context_window.used_percentage // empty')

# Shorten home directory to ~
home="$HOME"
short_cwd="${cwd/#$home/~}"

# Git branch (skip optional locks to avoid interference)
branch=""
if git -C "$cwd" rev-parse --is-inside-work-tree --no-optional-locks >/dev/null 2>&1; then
  branch=$(git -C "$cwd" symbolic-ref --short HEAD 2>/dev/null || git -C "$cwd" rev-parse --short HEAD 2>/dev/null)
fi

# Build the status line with ANSI colors
# Cyan for directory, magenta for git branch, dim for model/context
printf "\033[36m%s\033[0m" "$short_cwd"

if [ -n "$branch" ]; then
  printf " \033[38;2;255;255;255mon\033[0m \033[35m%s\033[0m" "$branch"
fi

if [ -n "$model" ]; then
  printf " \033[2m%s\033[0m" "$model"
fi

if [ -n "$used" ]; then
  printf " \033[2mcontext: %.0f%%\033[0m" "$used"
fi
