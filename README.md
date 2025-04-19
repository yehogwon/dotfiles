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

## Useful tools

### Local Installation

This repository also supports installation of packages. Run the following command to install packages:

```bash
$ dot-install <packages>
$ dot-install uninstall <packages>
```

> [!TIP]
> `bin/install` is a standalone script. If you want to install packages only without syncing dotfiles, you can run `bin/install` directly. This will not affect your system.

Once you sync your dotfiles, the default insatllation directory is `~/.dotfiles_bin/<package_name>`. You can set/change the installation directory by estting the `DF_INST_ROOT` environment variable before running the installation script.

FYI: the `bin` directory for each package (i.e., `$DF_INST_ROOT/<package_name>/bin`) is automatically added to the `PATH` variable once you sync your dotfiles. Please note that removing this is sufficient to uninstall the package.

### Wheel URL retriever

This repository also includes a script to retrieve the URLs of wheel files given index urls. 

If you want to install `<package_names>` packages from `<index_urls>`, you can run the following command to retrieve the wheel file names for the packages. This will save the wheel file names (for those not installed) in `<wheel_name_file>`:

```bash
(uv) $ uv pip install --dry-run <package_names> --index-url <index_urls> --verbose \
    2>&1 | grep '.whl' | grep -v '.metadata' | grep 'Selecting' | grep -oP '\(\K[^)]*(?=\))' > <wheel_name_file>
(pip) $ pip install --dry-run <package_names> --index-url <index_urls> --verbose \
    2>&1 | grep '.whl' | grep -v '.metadata' | grep -o '\S*\.whl\S*' > <wheel_name_file>
```

Then retrieve the URLs of the wheel files using the following command, which requires `requests`, `BeautifulSoup`, and `tqdm` Python packages:

```bash
$ python scripts/retrieve_wheels.py \
    --index_urls <index_url_file> \
    --wheels <wheel_name_file> \
    --output <output_file> \
    --url_only
```

Then the URLs should be saved in the `<output_file>`. You can download them using `wget` or `curl`. But for a parallel download, run the following command:

```bash
$ cd <dir_for_wheels>
$ cat <output_file> | xargs -n 1 -P <n_procs> wget
```

Once all the wheels are downloaded, you can install them using the following command:

```bash
(uv) $ uv pip install *.whl
(pip) $ pip install *.whl
```

The command below installs the packages that couldn't have been retrieved from the index URL. 

```bash
(uv) $ uv pip install <package_names>
(pip) $ pip install <package_names>
```
