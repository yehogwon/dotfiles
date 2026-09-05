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
- `settings.json`, layered onto `~/.claude/settings.json` at launch
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

`~/.claude/settings.json` is **not** managed wholesale — Claude Code rewrites it as
you change settings, and `bin/install-claude-hud` only ever writes the `statusLine`
key into it (`bin/uninstall` removes that key while it still points at this repo's
launcher). Settings worth carrying between machines live in `claude/settings.json`
instead, layered in from the outside: `shell/tools` defines a `claude` wrapper that
passes the file to `claude --settings`, which Claude Code treats as its own settings
source, ranked above `~/.claude/settings.json` and below managed policy. Nothing is
written to the live file, and the repo copy is read at every launch, so an edit
applies to the next session rather than the next `bin/install`.

What that file carries, and why each key has to be there rather than in the live file:

- `remoteControlAtStartup` — only honored from managed, `--settings`, or user
  settings; a repo-scoped `.claude/settings.json` can only turn it off.
- `extraKnownMarketplaces` and `enabledPlugins` — declaring the HUD makes a fresh
  machine install it on first launch, with no `bin/install-claude-hud` run.
- `statusLine` — the command runs through a shell, so `$DOTFILES_HOME` expands and
  one entry survives a checkout at any path.

Two limits come with the wrapper:

- It only covers `claude` started from a shell that sourced these dotfiles. The IDE
  extensions, the desktop app, scripts, and daemon-respawned sessions read
  `~/.claude/settings.json` directly and never see the repo copy — which is why
  `bin/install-claude-hud` still wires the HUD into the live file.
- A key here outranks the live file, so `/config` toggles for that key write to
  `~/.claude/settings.json` and silently do nothing. Remove the key to hand it back;
  `command claude` launches without the flag entirely.

`config.json` is handled differently again, because JSON has no include directive
and the plugin's own tooling writes that file: `claude/hud.json` is **copied** into
place, and a live file that differs is backed up beside itself before being
replaced. `bin/uninstall` leaves it there.

Because the config is a copy rather than an include, the two directions are manual:

```sh
# after editing the HUD with /claude-hud:configure, capture it
cp ~/.claude/plugins/claude-hud/config.json ~/.dotfiles/claude/hud.json

# after bin/update pulls a new hud.json, re-run install to apply it
~/.dotfiles/bin/install
```

Editing `~/.claude/settings.json` needs `python3`, as does the JSON check the
installer runs over `claude/settings.json`; without it the installer says so and
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
