#!/bin/bash
# Print compact git status for tmux: "branch [?U ±M +S ↑A ↓B]"
#   ?U  untracked files
#   ±M  modified tracked files (worktree, unstaged)
#   +S  staged changes
#   ↑A  commits ahead of upstream
#   ↓B  commits behind upstream (something to pull; relies on last fetch)
# Empty output when not a git repo.

path="$1"
if [ -z "$path" ] || [ "$path" = '#{pane_current_path}' ]; then
    path=$(tmux display-message -p '#{pane_current_path}' 2>/dev/null)
fi
[ -z "$path" ] && path="$PWD"
[ -d "$path" ] || exit 0

branch=$(git -C "$path" symbolic-ref --short HEAD 2>/dev/null) \
  || branch=$(git -C "$path" rev-parse --short HEAD 2>/dev/null) \
  || exit 0
[ -z "$branch" ] && exit 0

porc=$(git -C "$path" status --porcelain=v1 2>/dev/null)
untracked=0
mod=0
stg=0
if [ -n "$porc" ]; then
    while IFS= read -r line; do
        x="${line:0:1}"
        y="${line:1:1}"
        if [ "$x" = "?" ] && [ "$y" = "?" ]; then
            untracked=$((untracked+1))
            continue
        fi
        case "$x" in [MADRCU]) stg=$((stg+1)) ;; esac
        case "$y" in [MADRCU]) mod=$((mod+1)) ;; esac
    done <<< "$porc"
fi

ahead=0
behind=0
ab=$(git -C "$path" rev-list --left-right --count '@{u}...HEAD' 2>/dev/null)
if [ -n "$ab" ]; then
    behind=$(echo "$ab" | awk '{print $1+0}')
    ahead=$(echo "$ab" | awk '{print $2+0}')
fi

out="⎇ $branch"
[ "$untracked" -gt 0 ] && out="$out ?$untracked"
[ "$mod" -gt 0 ] && out="$out ±$mod"
[ "$stg" -gt 0 ] && out="$out +$stg"
[ "$ahead" -gt 0 ] && out="$out ↑$ahead"
[ "$behind" -gt 0 ] && out="$out ↓$behind"
echo "$out"
