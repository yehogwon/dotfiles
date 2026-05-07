#!/bin/bash
# Render the pane-border title.
# If a descendant of the pane shell is an ssh-like process, show "host";
# otherwise show the basename of the current working directory.
#
# Usage: pane_title.sh <pane_pid> <pane_active 0|1> <pane_path>
#                      <c_active_fg> <c_active_bg>
#                      <c_inactive_fg>
#                      <c_active_ssh_bg>

pane_pid=$1
pane_active=$2
pane_path=$3
c_active_fg=$4
c_active_bg=$5
c_inactive_fg=$6
c_assh_bg=$7

find_ssh_args() {
    local pid=$1 children child cmd args
    cmd=$(ps -p "$pid" -o comm= 2>/dev/null)
    cmd=${cmd##*/}
    case "$cmd" in
        ssh|mosh-client|autossh)
            ps -p "$pid" -o args= 2>/dev/null
            return 0
            ;;
    esac
    children=$(pgrep -P "$pid" 2>/dev/null) || return 1
    for child in $children; do
        if args=$(find_ssh_args "$child"); then
            printf '%s\n' "$args"
            return 0
        fi
    done
    return 1
}

ssh_args=$(find_ssh_args "$pane_pid")
host=""
if [ -n "$ssh_args" ]; then
    # shellcheck disable=SC2086
    set -- $ssh_args
    shift  # drop program name
    while [ $# -gt 0 ]; do
        case "$1" in
            # ssh flags that take a value
            -[bcDEeFIiJLlmOoPpQRSWw])
                shift; [ $# -gt 0 ] && shift; continue ;;
            -*)
                shift; continue ;;
            *)
                host=${1##*@}
                break ;;
        esac
    done
fi

if [ -n "$host" ]; then
    label=$host
    active_bg=$c_assh_bg
else
    label=${pane_path##*/}
    active_bg=$c_active_bg
fi

if [ "$pane_active" = "1" ]; then
    printf '#[fg=%s,bg=%s,bold] %s ' "$c_active_fg" "$active_bg" "$label"
else
    printf '#[fg=%s] %s ' "$c_inactive_fg" "$label"
fi
