#!/bin/sh
# Print one of two colors based on pane_current_command.
# Used by tmux pane-active-border-style.
#
# Usage: pane_border_color.sh <pane_current_command> <c_default> <c_ssh>

case "$1" in
    ssh|mosh-client|autossh) printf '%s' "$3" ;;
    *) printf '%s' "$2" ;;
esac
