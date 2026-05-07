#!/bin/bash
# Render the pane-border title.
# If pane_current_command is an ssh-like process, show the remote host;
# otherwise show the basename of the current working directory.
#
# Usage: pane_title.sh <pane_tty> <pane_current_command> <pane_active 0|1>
#                      <pane_path>
#                      <c_active_fg> <c_active_bg>
#                      <c_inactive_fg>
#                      <c_active_ssh_bg>

pane_tty=$1
pcc=$2
pane_active=$3
pane_path=$4
c_active_fg=$5
c_active_bg=$6
c_inactive_fg=$7
c_assh_bg=$8

host=""
case "$pcc" in
    ssh|mosh-client|autossh)
        ssh_args=$(ps -t "${pane_tty##*/}" -o args= 2>/dev/null | awk '
            {
                cmd = $1
                sub(/.*\//, "", cmd)
                if (cmd == "ssh" || cmd == "mosh-client" || cmd == "autossh") {
                    print
                    exit
                }
            }
        ')
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
        ;;
esac

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
