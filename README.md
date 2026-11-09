# `.dotfiles`

*A git-based manager for synchronizing dotfiles.*

## Installation

```sh
curl -fsSL https://raw.githubusercontent.com/yehogwon/dotfiles/main/bin/install | bash
source ~/.bashrc  # (or ~/.zshrc)
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

**config**
- `gitconfig`
- `vimrc`

**ghostty**
- `config`, included from Ghostty's own config file; on conflicts, settings here win.

**claude**
- `settings.json`, layered over your own `~/.claude/settings.json`; on conflicts, settings here win
- `mods/hud`, a HUD above the prompt (model, effort, context, usage, git, agents, todos)
- `skills/herdr-app`, `skills/herdr-core`

**herdr**
- `app`: Herdr's keys, the `tui` layout and mods
- `core`: hc's `config.toml` and agent templates

To override a linked file on one machine, replace the link with a real file.

**also automatically installs**
- `fzf`
- `oh-my-zsh`
- `tpm`

**misc.**

The `misc` directory contains some useful tools (at least for me) for managing clusters or doing fun stuff.

## Unplugging

Switch an area (`claude`, `herdr-app`, `herdr-core`) off on one machine, or back on:

```sh
dot unplug herdr-app
dot plug herdr-app
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
