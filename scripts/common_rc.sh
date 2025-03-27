shell_name=$(basename $SHELL)

if [ -f ~/.local_envs ]; then
    source ~/.local_envs
fi

if [ "$ONLY_NECESSARY" = 1 ]; then
    # Setup neovim
    export PATH="$HOME/nvim/bin:$PATH"
    if which nvim > /dev/null 2>&1; then
        alias vim='nvim'
        alias vi='nvim'
    fi

    # Now this dotfiles supports all machines!
    DOTSYNC_FILES="all"
    alias dot-push="source ~/.dotfiles/bin/push $DOTSYNC_FILES"
    alias dot-pull="source ~/.dotfiles/bin/pull $DOTSYNC_FILES"

    alias gs='git status'
    alias gp='git push'
    alias gc='git commit'
    alias ga='git add'
    alias gd='git diff'

    alias t='tmux'
    alias tls='tmux ls'
    alias ta='tmux attach'
    alias tat='tmux attach -t'

    alias squeue='squeue -o   "%6i %35j  %9T %12u %8g %15P %4D %20R %4C %13b %8m %11l %11L %p"'
    alias sq='squeue'
    alias sqyh='squeue -u yehok117'
    alias sqw='squeue -w'

    alias sq2080ti='squeue -p 2080ti'
    alias sq3090='squeue -p 3090'
    alias sqa5000='squeue -p A5000'
    alias sqa6000='squeue -p A6000'
    alias sqa100p='squeue -p A100-pci'
    alias sq4a100='squeue -p 4A100'
    alias sqa10040='squeue -p A100-40GB'
    alias sqa10080='squeue -p A100-80GB'
    alias sql40s='squeue -p L40S'

    # conda
    if [ -f "$HOME/.conda_init.sh" ]; then
        source ~/.conda_init.sh
    fi

    return 0
fi

# Setup fzf
if [[ ! "$PATH" == *$HOME/.fzf/bin* ]]; then
  PATH="${PATH:+${PATH}:}$HOME/.fzf/bin"
fi

if [ "$shell_name" = "bash" ]; then
    if which fzf > /dev/null; then
        eval "$(fzf --bash)" # This does keybindings and completion. Below not needed.
    fi

    if [ -f "$HOME/.fzf/shell/completion.bash" ]; then
        : # source "$HOME/.fzf/shell/completion.bash"
    fi

    if [ -f "$HOME/.fzf/shell/key-bindings.bash" ]; then
        : # source "$HOME/.fzf/shell/key-bindings.bash"
    fi
elif [ "$shell_name" = "zsh" ]; then
    if which fzf > /dev/null; then
        source <(fzf --zsh)
    fi

    if [ -f "$HOME/.fzf/shell/completion.zsh" ]; then
        : # source "$HOME/.fzf/shell/completion.zsh"
    fi

    if [ -f "$HOME/.fzf/shell/key-bindings.zsh" ]; then
        : # source "$HOME/.fzf/shell/key-bindings.zsh"
    fi
else
    echo "fzf unsupported shell: $shell_name"
    return 1
fi

if grep -q "^Host c2-1" ~/.ssh/config 2>/dev/null; then
    alias serverstat="ssh c2-1 -L 33425:localhost:48109"
fi

# flutter
if [ -n "${FLUTTER_HOME}" ]; then
    export PATH="$FLUTTER_HOME/bin:$PATH"
fi

unset shell_name
