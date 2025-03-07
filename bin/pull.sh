#! /bin/bash

CWD=$(pwd)

echo "Are you sure you want to download dotfiles and link them to your local ones?"
echo " (y/n) > "
read -n 1 -s answer
echo

function link() {
    cd "$(dirname "$0")/.."
    
    # bash
    ln -s "bash/bashrc" "~/.bashrc"
    ln -s "bash/inputrc" "~/.inputrc"

    # tmux
    ln -s "tmux/tmux.conf" "~/.tmux.conf"

    # vim
    ln -s "vim/vimrc" "~/.vimrc"

    # git
    ln -s "git/gitconfig" "~/.gitconfig"

    # ssh
    ln -s "ssh/authorized_keys" "~/.ssh/authorized_keys"
}

function bash() {
    source ~/.bashrc 1> /dev/null 2>&1
}

function tmux() {
    tmux source ~/.tmux.conf 1> /dev/null 2>&1
}

function vim() {
    # do nothing
}

function git() {
    # do nothing
}

function cd_exit() {
    cd "$CWD"
    exit "$1"
}

if [ "$answer" = "y" ]; then
    echo "Downloading dotfiles from GitHub..."
    cd "$(dirname "$0")/.."
    if git pull; then
        echo "Dotfiles downloaded successfully."
    else
        echo "Failed to download dotfiles."
        cd_exit 1
    fi

    echo "Linking dotfiles..."
    link
    echo "Dotfiles linked successfully."
    
    echo "Sourcing changes..."
    bash
    tmux
    vim
    echo "Changes sourced successfully."
else
    echo "Download cancelled."
    cd_exit 0
fi
