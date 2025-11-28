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

alias squeue='squeue -o   "%8i %30j  %9T %12u %8g %9P %4D %8R %4C %13b %8m %11l %11L %p"'
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

wwatch() {
  local interval=1 alt=1

  # options
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -n|--interval) interval="$2"; shift 2 ;;
      --no-alt)      alt=0; shift ;;
      --)            shift; break ;;
      *)             break ;;
    esac
  done

  # require a command
  if [[ $# -eq 0 ]]; then
    printf 'usage: wwatch [-n SEC] [--no-alt] -- <cmd> [args...]\n' >&2
    return 1
  fi

  # enter alternate screen (if requested)
  if (( alt )); then
    # prefer terminfo where available
    if command -v tput >/dev/null 2>&1; then tput smcup; else printf '\e[?1049h'; fi
  fi

  # cleanup
  local interrupted=0
  cleanup() {
    interrupted=1
    if (( alt )); then
      if command -v tput >/dev/null 2>&1; then tput rmcup; else printf '\e[?1049l'; fi
    fi
    stty sane
  }
  trap cleanup INT TERM HUP EXIT

  # main loop
  while (( !interrupted )); do
    printf '\033[H\033[2J'
    print_yellow "wwatch :: $(hostname) :: $(date)"
    eval "$@"
    for ((i=0; i<interval && !interrupted; i++)); do sleep 1; done
  done
}


function rjump() {
    set -e

    src=$1
    dst=$2

    if [ -z "$src" ] || [ -z "$dst" ]; then
        print_red "Usage: rjump <src> <dst>"
        return 1
    fi
    
    _temp_dir=$(mktemp -d)
    _fname=$(basename "$src") # TODO: Prevent from being removed by OS

    print_yellow "rsyncing ..."

    # TODO: Show the estimated size of the transfer
    # print_green "Estimating size ..."
    # rsync -avh --dry-run --stats "ssh -C" "$src" "$_temp_dir"

    # read -p "Continue? (y/n) " -n 1 -r
    # echo
    # if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    #     print_red "Aborted."
    #     return 1
    # fi
    
    print_yellow "Downloading ..."
    rsync -avz --partial -e "ssh -C" "$src" "$_temp_dir"
    
    print_yellow "Uploading ..."
    rsync --remove-source-files -avz --partial -e "ssh -C" "$_temp_dir/$_fname" "$dst"
}

function git_pull_all() {
    git branch -r \
    | grep -v '\->' \
    | sed "s,\x1B\[[0-9;]*[a-zA-Z],,g" \
    | while read remote; do \
        git branch --track "${remote#origin/}" "$remote"; \
    done
    
    git fetch --all
    git pull --all
}

alias git-pull-all=git_pull_all

function slurm_out() {
    if [ "$#" -ne 1 ]; then
        print_red "Usage: slurm_out <job_id>"
        return 1
    fi

    job_id=$1
    out_file=$(scontrol show job $job_id | awk -F= '/StdOut/{print $2}')
    status=${PIPESTATUS[0]}

    if [ $status -ne 0 ]; then
        print_red "Failed to get output file for job $job_id"
        return 1
    else
        echo "$out_file"
        return 0
    fi
}

function slurm_err() {
    if [ "$#" -ne 1 ]; then
        print_red "Usage: slurm_err <job_id>"
        return 1
    fi

    job_id=$1
    out_file=$(scontrol show job $job_id | awk -F= '/StdErr/{print $2}')
    status=${PIPESTATUS[0]}

    if [ $status -ne 0 ]; then
        print_red "Failed to get error file for job $job_id"
        return 1
    else
        echo "$out_file"
        return 0
    fi
}

function cat_out() {
    if [ "$#" -ne 1 ]; then
        print_red "Usage: cat_out <job_id>"
        return 1
    fi

    job_id=$1
    out_file=$(slurm_out $job_id)

    if [ $? -ne 0 ]; then
        print_red "Failed to get output file for job $job_id"
        return 1
    else
        print_green "Displaying output file: $out_file"
        cat "$out_file"
        return 0
    fi
}

function track_out() {
    if [ "$#" -ne 1 ]; then
        print_red "Usage: track_out <job_id>"
        return 1
    fi

    job_id=$1
    out_file=$(slurm_out $job_id)

    if [ $? -ne 0 ]; then
        print_red "Failed to get output file for job $job_id"
        return 1
    else
        print_green "Tracking output file: $out_file"
        tail -f "$out_file"
        return 0
    fi
}

function cat_err() {
    if [ "$#" -ne 1 ]; then
        print_red "Usage: cat_err <job_id>"
        return 1
    fi

    job_id=$1
    err_file=$(slurm_err $job_id)

    if [ $? -ne 0 ]; then
        print_red "Failed to get error file for job $job_id"
        return 1
    else
        print_green "Displaying error file: $err_file"
        cat "$err_file"
        return 0
    fi
}

function track_err() {
    if [ "$#" -ne 1 ]; then
        print_red "Usage: track_err <job_id>"
        return 1
    fi

    job_id=$1
    err_file=$(slurm_err $job_id)

    if [ $? -ne 0 ]; then
        print_red "Failed to get error file for job $job_id"
        return 1
    else
        print_green "Tracking error file: $err_file"
        tail -f "$err_file"
        return 0
    fi
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

export EDITOR=vim
export PATH="$HOME/.local/bin:$PATH"
