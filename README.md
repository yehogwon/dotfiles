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

**claude**
- `claude-hud` `config.json`

Unlike every other managed file, JSON has no include directive, so the HUD config
is *copied* into `${CLAUDE_CONFIG_DIR:-~/.claude}/plugins/claude-hud/config.json`
instead of being wrapped in a managed block. `claude/hud.json` is the source of
truth: a live file that differs is backed up next to itself before being replaced,
and `bin/uninstall` leaves it in place.

Because it is a copy rather than an include, the two directions are manual:

```sh
# after editing the HUD with /claude-hud:configure, capture it
cp ~/.claude/plugins/claude-hud/config.json ~/.dotfiles/claude/hud.json

# after bin/update pulls a new hud.json, re-run install to apply it
~/.dotfiles/bin/install
```

The statusline wiring itself (`statusLine`, `enabledPlugins`,
`extraKnownMarketplaces` in `~/.claude/settings.json`) is *not* managed here —
Claude Code rewrites that file as you change settings. Use the plugin's own
`/claude-hud:setup` on a new machine.

**also automatically installs**
- `fzf`
- `oh-my-zsh`
- `tpm`

**misc.**

The `misc` directory contains some useful tools (at least for me) for managing clusters or doing fun stuff.

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
