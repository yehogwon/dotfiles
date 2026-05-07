#!/bin/bash
# Print one of two colors depending on whether the pane has an ssh-like
# descendant. Used by tmux pane-active-border-style.
#
# Usage: pane_border_color.sh <pane_pid> <color_default> <color_ssh>

pane_pid=$1
c_default=$2
c_ssh=$3

has_ssh() {
    local pid=$1 children child cmd
    cmd=$(ps -p "$pid" -o comm= 2>/dev/null)
    cmd=${cmd##*/}
    case "$cmd" in
        ssh|mosh-client|autossh) return 0 ;;
    esac
    children=$(pgrep -P "$pid" 2>/dev/null) || return 1
    for child in $children; do
        has_ssh "$child" && return 0
    done
    return 1
}

if has_ssh "$pane_pid"; then
    printf '%s' "$c_ssh"
else
    printf '%s' "$c_default"
fi
