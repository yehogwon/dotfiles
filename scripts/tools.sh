DF_INST_ROOT="$HOME/.dotfiles_bin"

function is_bash() {
    # using $BASH_VERSION
    if [ -n "$BASH_VERSION" ]; then
        return 0
    fi
    return 1
}

function is_zsh() {
    # using $ZSH_VERSION
    if [ -n "$ZSH_VERSION" ]; then
        return 0
    fi
    return 1
}
