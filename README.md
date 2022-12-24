# Dotfiles

Repository created to manage my personal Dotfiles. Based on: https://www.atlassian.com/git/tutorials/dotfiles

```bash
alias config='/usr/bin/git --git-dir=$HOME/.cfg/ --work-tree=$HOME'
echo ".cfg" >> .gitignore
git clone --bare <git-repo-url> $HOME/.cfg
config checkout
```
