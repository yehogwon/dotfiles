#!/bin/bash
# Print compact Obsidian vault sync status for tmux: "ob <glyph>"
#   ●      synced with the remote
#   ↑N     N local commits not yet pushed
#   ○      remote unreachable (○ ↑N when commits are also waiting)
#   !      conflict parked; sync will not advance until a human clears it
#   ✗      repo broken — detached HEAD, no remote, wedged rebase
#   ?Nm    the status file went stale N ago: sync is not running at all
# Glyphs and colors follow the vault's .bin/status dashboard. Age outranks the
# state: sync rewrites the file every run, so a stale "synced" means it died.
# Empty output when this machine has no vault sync installed.
#
# Usage: obsidian_status.sh <state_dir> <c_label> <c_synced> <c_ahead> <c_offline> <c_alert> <c_sep>
# Env: VAULT_SYNC_STATE (state dir), VAULT_STATUS_STALE_S (stale after, 60)

state_dir="$1"
c_label="$2"
c_synced="$3"
c_ahead="$4"
c_offline="$5"
c_alert="$6"
c_sep="$7"

[ -z "$state_dir" ] && state_dir="${VAULT_SYNC_STATE:-$HOME/.cache/vault-sync}"
status_file="$state_dir/status.json"
[ -s "$status_file" ] || exit 0

IFS= read -r json < "$status_file" 2>/dev/null || exit 0
[ -n "$json" ] || exit 0

# By key, not position, so the writer's field order can change. $3=1 if quoted.
extract() {
    local s="$1" key="$2"
    case "$s" in
        *"\"$key\":"*) ;;
        *) return 1 ;;
    esac
    s="${s#*\"$key\":}"
    if [ "$3" = 1 ]; then
        s="${s#\"}"
        printf '%s' "${s%%\"*}"
    else
        printf '%s' "${s%%,*}"
    fi
}

state="$(extract "$json" state 1)" || exit 0
epoch="$(extract "$json" epoch 0)" || epoch=""
ahead="$(extract "$json" ahead 0)" || ahead=""

# tmux re-expands `#` in #() output, so nothing unvalidated may reach it.
state="${state//[^a-z-]/}"
[ -n "$state" ] || state="unknown"
[[ "$epoch" =~ ^[0-9]+$ ]] || epoch=""
[[ "$ahead" =~ ^[0-9]+$ ]] || ahead=0

stale_after="${VAULT_STATUS_STALE_S:-60}"
[[ "$stale_after" =~ ^[0-9]+$ ]] || stale_after=60

# style, text -> segment + separator. #[default] keeps bold off the separator.
emit() {
    printf '#[fg=%s]ob #[%s]%s#[default] #[fg=%s]· ' "$c_label" "$1" "$2" "$c_sep"
}

age=""
if [ -n "$epoch" ]; then
    age=$(( $(date +%s) - epoch ))
    [ "$age" -lt 0 ] && age=0   # a clock that moved back is not a fault
fi

if [ -n "$age" ] && [ "$age" -gt "$stale_after" ]; then
    if [ "$age" -lt 3600 ]; then
        label="$(( age / 60 ))m"
    elif [ "$age" -lt 86400 ]; then
        label="$(( age / 3600 ))h"
    else
        label="$(( age / 86400 ))d"
    fi
    emit "fg=$c_alert,bold" "?$label"
    exit 0
fi

case "$state" in
    synced)   emit "fg=$c_synced" "●" ;;
    ahead)    [ "$ahead" -gt 0 ] && emit "fg=$c_ahead" "↑$ahead" || emit "fg=$c_ahead" "↑" ;;
    offline)  [ "$ahead" -gt 0 ] && emit "fg=$c_offline" "○ ↑$ahead" || emit "fg=$c_offline" "○" ;;
    conflict) emit "fg=$c_alert,bold" "!" ;;
    error)    emit "fg=$c_alert" "✗" ;;
    # An unknown state: name it rather than guess a severity. Safe, stripped above.
    *)        emit "fg=$c_offline" "${state:0:12}" ;;
esac
