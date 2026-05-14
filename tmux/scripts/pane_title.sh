#!/bin/bash
# Render the pane-border title.
# If pane_current_command is an ssh-like process, show the remote host.
# Else if su is running on the pane's tty (including the common case where
# pane_current_command is the child shell spawned by su), show the target
# user as "su:<user>".
# Otherwise show the basename of the current working directory.
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

tty_name=${pane_tty##*/}
label=""
active_bg=$c_active_bg

case "$pcc" in
    ssh|mosh-client|autossh)
        ssh_args=$(ps -t "$tty_name" -o args= 2>/dev/null | awk '
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
                        label=${1##*@}
                        active_bg=$c_assh_bg
                        break ;;
                esac
            done
        fi
        ;;
esac

# su keeps a child shell as the pane's foreground process, so pcc won't
# announce it -- scan the tty's process list instead.
if [ -z "$label" ]; then
    su_args=$(ps -t "$tty_name" -o args= 2>/dev/null | awk '
        {
            cmd = $1
            sub(/.*\//, "", cmd)
            if (cmd == "su") {
                print
                exit
            }
        }
    ')
    if [ -n "$su_args" ]; then
        # shellcheck disable=SC2086
        set -- $su_args
        shift  # drop program name
        target="root"
        while [ $# -gt 0 ]; do
            case "$1" in
                # su flags that take a value
                -c|--command|-g|--group|-G|--supp-group|-s|--shell|--session-command)
                    shift; [ $# -gt 0 ] && shift; continue ;;
                -*)
                    shift; continue ;;
                *)
                    target=$1
                    break ;;
            esac
        done
        label="su:$target"
        active_bg=$c_assh_bg
    fi
fi

if [ -z "$label" ]; then
    label=${pane_path##*/}
fi

if [ "$pane_active" = "1" ]; then
    printf '#[fg=%s,bg=%s,bold] %s ' "$c_active_fg" "$active_bg" "$label"
else
    printf '#[fg=%s] %s ' "$c_inactive_fg" "$label"
fi
