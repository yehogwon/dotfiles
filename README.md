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
- [`claude-hud`](https://github.com/jarrodwatts/claude-hud) plugin, its statusline wiring, and `config.json`

When `claude` is on `PATH`, the installer offers to set up the HUD end to end:
it registers the marketplace, installs the plugin, points `statusLine` at
`claude/hud-statusline`, and drops `claude/hud.json` into place. Answer `n`
(or set `INSTALL_CLAUDE_HUD=n`) to skip the plugin and keep just the config copy.

That prompt is skipped without asking when there is no terminal to ask on, which
includes the `curl … | bash` bootstrap above. Set `INSTALL_CLAUDE_HUD=y` to wire
the HUD there, or run `bin/install-claude-hud` afterwards; it is idempotent.

`claude/hud-statusline` replaces the one-liner `/claude-hud:setup` writes. That
one-liner bakes in the absolute path of the runtime it found at setup time, which
does not survive being carried to another machine; the launcher resolves the
plugin directory and the runtime (bun, else node) on every call instead, so a
single `settings.json` entry works everywhere.

Two things are handled differently from every other managed file, both because
JSON has no include directive:

- `config.json` is **copied**, not included. `claude/hud.json` is the source of
  truth, and a live file that differs is backed up beside itself before being
  replaced. `bin/uninstall` leaves it in place.
- `settings.json` is **not** managed wholesale — Claude Code rewrites it as you
  change settings. Only the `statusLine` key is written, and `bin/uninstall`
  removes it only while it still points at this repo's launcher.

Because the config is a copy rather than an include, the two directions are manual:

```sh
# after editing the HUD with /claude-hud:configure, capture it
cp ~/.claude/plugins/claude-hud/config.json ~/.dotfiles/claude/hud.json

# after bin/update pulls a new hud.json, re-run install to apply it
~/.dotfiles/bin/install
```

Editing `settings.json` needs `python3`; without it the installer says so and
points at `/claude-hud:setup`. The plugin itself needs `bun` or `node` at runtime.

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
