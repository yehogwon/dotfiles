if [ -f ~/.tools.sh ]; then
    source ~/.tools.sh
fi

shell_name="none"
if is_bash; then
    shell_name="bash"
elif is_zsh; then
    shell_name="zsh"
fi

if [ -f ~/.local_envs ]; then
    source ~/.local_envs
fi

# Setup dotfiles bin
export DF_INST_ROOT="${DF_INST_ROOT:-$HOME/.dotfiles_bin}"
if [ -d "$DF_INST_ROOT" ]; then
    if [ "$(ls -A $DF_INST_ROOT)" ]; then
        for dir in "$DF_INST_ROOT"/*; do
            if [ -d "$dir/bin" ]; then
                PATH="$dir/bin:$PATH"
            fi
        done
    fi
fi

if which nvim > /dev/null 2>&1; then
    alias vim='nvim'
    alias vi='nvim'
fi

SCRIPT_PATH="$(realpath "${BASH_SOURCE[0]:-$0}")"
export DOTFILES_DIR="$(realpath "$(dirname "$SCRIPT_PATH")/..")"
DOTSYNC_FILES="all"

alias dot-push="source $DOTFILES_DIR/bin/push $DOTSYNC_FILES"
alias dot-pull="source $DOTFILES_DIR/bin/pull $DOTSYNC_FILES"
alias dot-install="$DOTFILES_DIR/bin/install"

alias dot-wheel="$DOTFILES_DIR/scripts/retrieve_wheels.sh"

alias gs='git status'
alias gp='git push'
alias gc='git commit'
alias ga='git add'
alias gd='git diff'

alias t='tmux'
alias tls='tmux ls'
alias tns='tmux new-session -s'
alias ta='tmux attach'
alias tat='tmux attach -t'

alias squeue='squeue -o   "%8i %30j  %9T %12u %8g %15P %4D %20R %4C %13b %8m %11l %11L %p"'
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

if [[ "$(hostname)" =~ ^kwak[0-9]+$ ]]; then
    alias ssh='ssh -p10022'
fi

function wwatch() {
    if [ -z "$1" ]; then
        print_red "wwatch: no command provided"
        return 1
    fi

    # Use alternate screen buffer
    echo -e "\e[?1049h"

    # Internal flag to break the loop
    interrupted=false

    # Cleanup handler
    cleanup() {
        interrupted=true
        echo -e "\e[?1049l"
        stty sane
    }

    # Set traps
    trap cleanup INT EXIT HUP

    # Main loop
    while true; do
        if $interrupted; then
            break
        fi
        clear
        print_yellow "wwatch :: $(hostname) :: $(date)"
        eval "$@"
        sleep 1
    done
}

# nvitop
if command -v uvx 2>&1 >/dev/null; then
    alias nvitop='uvx nvitop'
elif command -v pipx 2>&1 >/dev/null; then
    alias nvitop='pipx run nvitop'
fi

# conda
_shell_name_bak="$shell_name"
if [ -f "$HOME/.conda_init.sh" ]; then
    source ~/.conda_init.sh
fi
shell_name="$_shell_name_bak"
unset _shell_name_bak

if [ "$ONLY_NECESSARY" = 1 ]; then
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
