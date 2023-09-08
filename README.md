# 🗂️ Dotfiles

This repository is dedicated to managing my personal dotfiles, offering a centralized and organized space to store and version control configuration files for various applications and tools. Customize your computing environment effortlessly by exploring and utilizing these dotfiles, ensuring a seamless and tailored experience across multiple platforms.

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/emiliosheinz/dotfiles/main/setup.sh)"
alias config='/usr/bin/git --git-dir=$HOME/.cfg/ --work-tree=$HOME'
echo ".cfg" >> .gitignore
git clone --bare <git-repo-url> $HOME/.cfg
config checkout
```

This repo was based on https://www.atlassian.com/git/tutorials/dotfiles tutorial.
