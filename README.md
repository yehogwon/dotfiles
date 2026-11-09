# `.dotfiles`

*A git-based manager for synchronizing dotfiles.*

## Installation

```sh
curl -fsSL https://raw.githubusercontent.com/yehogwon/dotfiles/main/bin/install | bash
source ~/.bashrc  # (or ~/.zshrc)
```
## Uninstallation

```sh
~/.dotfiles/bin/uninstall
source ~/.bashrc  # (or ~/.zshrc)
```

You can also uninstall with a remote script and remove the dir manually:

```sh
curl -fsSL https://raw.githubusercontent.com/yehogwon/dotfiles/main/bin/uninstall | bash
rm -dr ~/.dotfiles
source ~/.bashrc  # (or ~/.zshrc)
```

Running the uninstall script also removes the dotfiles checkout that contains that script.
