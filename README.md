# `.dotfiles`

*A git-based manager for synchronizing dotfiles.*

## Installation

```sh
$ curl -fsSL https://raw.githubusercontent.com/yehogwon/dotfiles/main/bin/install | bash
$ source ~/.bashrc  # (or ~/.zshrc)
```

## What It Manages

**shell**
- `bashrc`
- `bash_profile`
- `inputrc`
- `zshrc`
- `zprofile`
- `zshenv`
- `zlogin`
- `zlogout`

**tmux**
- `tmux.conf`
- plugins: `tmux-powerline`

**misc.**
- `gitconfig`
- `vimrc`

**also automatically installs**
- `fzf`
- `oh-my-zsh`
- `tpm`

## Uninstallation

```sh
$ ~/.dotfiles/bin/uninstall
$ source ~/.bashrc  # (or ~/.zshrc)
```
