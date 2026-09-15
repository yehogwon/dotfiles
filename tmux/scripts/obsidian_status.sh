#!/bin/bash
# Print compact Obsidian vault sync status for tmux: "vault <glyph>"
#   ✓      synced — the working tree matches the remote
#   ↑N     N local commits not yet pushed
#   ⊘      remote unreachable (⊘ ↑N when commits are also waiting)
#   !      a conflict is parked and sync will not advance until a human clears it
#   ✗      the repo itself is broken — detached HEAD, no remote, wedged rebase
#   ?Nm    the status file itself went stale N minutes ago: sync is not running
# Empty output when this machine has no vault sync installed.
#
# The vault replicates over git — `.bin/sync` in the vault fetches, commits and
# pushes every ten seconds — and its documented blind spot is that every way it
# can stop is silent. A rebase conflict aborts cleanly, pushes nothing, and
# logs to a file nobody reads; a laptop that never woke, a timer that was never
# loaded, and a supervising loop that died are quieter still. One such stall
# ran 14h11m before anyone noticed, 41 commits behind. This is that fault made
# visible at a glance, in the one place already on screen all day.
#
# WHERE THE STATE COMES FROM
#
# `.bin/sync` renders one JSON status line per run and writes it to two sinks:
# `.sync-status.json` inside the vault, and `status.json` beside its log in the
# state dir. Both come from a single printf in a single call, so they cannot
# disagree. This reads the state-dir copy ONLY, and that is deliberate:
#
#   - dotfiles is shared across machines, and the vault sits at a different
#     path — or at no path — on each of them. The state dir does not: it is a
#     fixed location that the vault's own installer creates on every machine
#     that runs sync. So this script needs no per-machine configuration, which
#     is the whole reason to prefer the sibling file over the in-vault one.
#   - its mere existence is then the honest answer to "is sync installed on
#     this machine", which the vault copy cannot give. An absent vault file is
#     equally a machine that never installed sync and one whose timer died
#     before it ever wrote — and those want opposite treatment here.
#
# The in-vault copy survives for Obsidian mobile, which reads it through the
# vault API and cannot see outside the vault. Nothing here should read it.
#
# WHY SYNCED IS SHOWN RATHER THAN HIDDEN
#
# Every mode flag on this bar (prefix, copy, mouse, sync, cwd) shows only while
# active, so hiding ✓ would match that habit — but it would also make silence
# ambiguous between "everything is fine" and "this script is broken, or the
# vault is gone". Recovering an unnoticed stall is the entire point, so the
# quiet state has to be visibly quiet rather than absent. It is dimmed instead.
#
# WHY STALENESS OUTRANKS WHATEVER THE FILE SAYS
#
# Sync rewrites the file on every run, including runs with nothing to do, so
# freshness is the only thing that separates "idle" from "not running at all".
# A stale `synced` is precisely the 14h11m failure, and it looks perfect. So
# age is checked before the state is read, and it wins: once the file stops
# being rewritten, nothing in it can be trusted, including good news. The
# reason for the stall is in the log, and `.bin/status` shows every machine.
#
# Usage: obsidian_status.sh <state_dir> <c_synced> <c_ahead> <c_offline> <c_alert> <c_sep>
#   state_dir  where sync keeps its state; empty for the default. Passed as a
#              tmux option so the lookup costs no subprocess.
# Env: VAULT_SYNC_STATE     same override the vault's own scripts honor
#      VAULT_STATUS_STALE_S seconds before the file is called stale (default 60,
#                           six missed ticks of sync's ten-second cadence)
#
# This runs once per status-interval, so it forks once (for the clock) and
# reads one short line. Everything emitted is either a literal or an integer
# this script validated, because tmux re-expands `#` sequences in the output of
# a `#()` command — no unvalidated byte from the file may reach the format.

state_dir="$1"
c_synced="$2"
c_ahead="$3"
c_offline="$4"
c_alert="$5"
c_sep="$6"

[ -z "$state_dir" ] && state_dir="${VAULT_SYNC_STATE:-$HOME/.cache/vault-sync}"
status_file="$state_dir/status.json"

# No sync on this machine: say nothing rather than nag about a vault that was
# never meant to be here.
[ -s "$status_file" ] || exit 0

json=""
IFS= read -r json < "$status_file" 2>/dev/null || exit 0
[ -n "$json" ] || exit 0

# Pull each field by its own key, so a change to the writer's field order
# cannot silently shift which value is read.
extract() {
    # $1 = json, $2 = key, $3 = 1 when the value is quoted
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

# Anything emitted has to be safe for tmux to re-expand.
state="${state//[^a-z-]/}"
[ -n "$state" ] || state="unknown"
[[ "$epoch" =~ ^[0-9]+$ ]] || epoch=""
[[ "$ahead" =~ ^[0-9]+$ ]] || ahead=0

stale_after="${VAULT_STATUS_STALE_S:-60}"
[[ "$stale_after" =~ ^[0-9]+$ ]] || stale_after=60

# style, text -> one status segment plus its trailing separator.
# `#[default]` resets bold before the separator so it cannot inherit it.
emit() {
    printf '#[%s]vault %s#[default] #[fg=%s]· ' "$1" "$2" "$c_sep"
}

age=""
if [ -n "$epoch" ]; then
    age=$(( $(date +%s) - epoch ))
    # A clock that moved backwards must not read as a fault.
    [ "$age" -lt 0 ] && age=0
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
    synced)
        emit "fg=$c_synced" "✓"
        ;;
    ahead)
        if [ "$ahead" -gt 0 ]; then
            emit "fg=$c_ahead" "↑$ahead"
        else
            emit "fg=$c_ahead" "↑"
        fi
        ;;
    offline)
        if [ "$ahead" -gt 0 ]; then
            emit "fg=$c_offline" "⊘ ↑$ahead"
        else
            emit "fg=$c_offline" "⊘"
        fi
        ;;
    conflict)
        emit "fg=$c_alert,bold" "!"
        ;;
    error)
        emit "fg=$c_alert" "✗"
        ;;
    *)
        # A state this script has not been taught. Name it rather than guess at
        # a severity: it is already stripped to [a-z-] above, so it is safe to
        # print, and a wrong colour would be worse than a plain report.
        emit "fg=$c_offline" "${state:0:12}"
        ;;
esac
