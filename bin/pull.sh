#! /bin/bash

if [ -n "$ZSH_VERSION" ]; then
    # zsh specific
    if [[ $ZSH_EVAL_CONTEXT =~ :file$ ]]; then
        sourced=1
    else
        sourced=0
    fi
elif [ -n "$BASH_VERSION" ]; then
    # bash specific
    if [[ "${BASH_SOURCE[0]}" != "$0" ]]; then
        sourced=1
    else
        sourced=0
    fi
else
    echo "\e[1;31mThis shell($SHELL) is not supported.\e[0m"
    exit 1
fi

if [ $sourced -eq 0 ]; then
    echo -e "\e[1;31mError: This script must be sourced, not executed.\e[0m"
    echo -e "\e[1;31mUsage: source $0\e[0m"
    exit 1
fi

CWD=$(pwd)

SCRIPT_PATH="$(realpath "${BASH_SOURCE[0]:-$0}")"
SCRIPT_DIR="$(dirname "$SCRIPT_PATH")"
DOTFILES_DIR="$(realpath "$SCRIPT_DIR/..")" # does not end with a slash

function link()
{
    # bash
    rm -f "$HOME/.bashrc"
    ln -s "$DOTFILES_DIR/bash/bashrc" "$HOME/.bashrc"

    rm -f "$HOME/.inputrc"
    ln -s "$DOTFILES_DIR/bash/inputrc" "$HOME/.inputrc"

    # tmux
    rm -f "$HOME/.tmux.conf"
    ln -s "$DOTFILES_DIR/tmux/tmux.conf" "$HOME/.tmux.conf"

    # vim
    rm -f "$HOME/.vimrc"
    ln -s "$DOTFILES_DIR/vim/vimrc" "$HOME/.vimrc"

    # git
    rm -f "$HOME/.gitconfig"
    ln -s "$DOTFILES_DIR/git/gitconfig" "$HOME/.gitconfig"
}

function return() {
    cd "$CWD"
}

echo -e "\e[1;31mDownloading dotfiles from GitHub...\e[0m"
cd "$DOTFILES_DIR"
if git pull; then
    echo -e "\e[1;31mDotfiles downloaded successfully.\e[0m"
else
    echo -e "\e[1;31mFailed to download dotfiles.\e[0m"
    return
fi

echo -e "\e[1;31mLinking dotfiles...\e[0m"
link
echo -e "\e[1;31mDotfiles linked successfully.\e[0m"

echo -e "\e[1;31mSourcing changes...\e[0m"
source $HOME/.bashrc 1> /dev/null 2>&1
bind -f $HOME/.inputrc
tmux source $HOME/.tmux.conf 1> /dev/null 2>&1

echo -e "\e[1;31mChanges sourced successfully.\e[0m"
return
