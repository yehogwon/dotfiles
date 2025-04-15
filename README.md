# `.dotfiles`

This repository contains my personal `.dotfiles` for my system. These dotfiles are synced across Kwak's servers.

## Managed dotfiles

The following dotfiles are included:

- [x] `~/.bashrc`
- [x] `~/.inputrc`
- [x] `~/.tmux.conf` (and other `tmux` configs and plugins)
- [x] `~/.vimrc`
- [x] `~/.gitconfig`
- [x] `~/.ssh/authorized_keys`
- [x] `oh-my-zsh`
- [x] `~/.zshrc` (and other `zsh` configs)
- [x] `conda`
- [x] `fzf`

*To be added:*

- [ ] `nvim`

## How to sync

> [!TIP]
> You can run these scripts wherever you are in your terminal. This script will affect the current shell immediately.

### Download dotfiles (i.e., `pull`)

To download the dotfiles from the remote repository and apply them to the local machine, run the following command:

> [!CAUTION]
> You should not execute `pull` without `source`-ing. In other words, you should not execute something like `./bin/pull` or `bash bin/pull`. Also, this only supports `bash` and `zsh`.

```bash
$ source bin/pull
```

Once you pull the dotfiles for the first time, you can run `dot-pull` to pull the dotfiles.

```bash
$ dot-pull
```

### Upload dotfiles (i.e., `push`)

To upload the dotfiles to the remote repository, run the following command:

```bash
$ source bin/push
```

Similarly, once you pull the dotfiles, you can run `dot-push` to push the dotfiles.

```bash
$ dot-push
```

This writes a commit message automatically using an LLM.

## Local environment variables

To set local environment variables, add them to the `~/.local_envs` file directly.

## Local Installation

This repository also supports installation of packages. Run the following command to install packages:

```bash
$ dot-install <packages>
$ dot-install uninstall <packages>
```

> [!TIP]
> `bin/install` is a standalone script. If you want to install packages only without syncing dotfiles, you can run `bin/install` directly. This will not affect your current shell.

The default installation directory is `~/.dotfiles_bin/<package_name>` (as long as you have synced the dotfiles). Removing this is sufficient to uninstall the package. 

If you want to change the installation directory, set the `DF_INST_ROOT` environment variable before running the installation script. 