#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -eq 0 ]; then
    echo 'Wrapper misconfigured: no allowed commands provided.' >&2
    exit 1
fi

print_allowed_commands() {
    echo 'Allowed commands:' >&2
    for x in "$@"; do
        echo "  $x" >&2
    done
}

orig="${SSH_ORIGINAL_COMMAND-}"

if [ -z "$orig" ]; then
    echo 'No command provided.' >&2
    print_allowed_commands "$@"
    exit 1
fi

case "$orig" in
    *';'*|*'&'*|*'|'*|*'$('*|*'`'*|*'>'*|*'<'*)
        echo 'Metacharacters not allowed.' >&2
        exit 1
        ;;
esac

set -f

if ! mapfile -d '' -t argv < <(
    /usr/bin/python3 -c '
import shlex
import sys

try:
    argv = shlex.split(sys.argv[1], posix=True)
except ValueError as exc:
    print(exc, file=sys.stderr)
    sys.exit(1)

for arg in argv:
    sys.stdout.buffer.write(arg.encode() + b"\0")
' "$orig"
); then
    echo 'Failed to parse command.' >&2
    exit 1
fi

if [ "${#argv[@]}" -eq 0 ]; then
    echo 'No command provided.' >&2
    print_allowed_commands "$@"
    exit 1
fi

cmd="${argv[0]}"

allowed=0
for x in "$@"; do
    if [ "$cmd" = "$x" ]; then
        allowed=1
        break
    fi
done

if [ "$allowed" -ne 1 ]; then
    echo "Command not allowed: $cmd" >&2
    print_allowed_commands "$@"
    exit 1
fi

export PATH='/usr/bin:/bin:/usr/sbin:/sbin'

exec /bin/bash -lc '
if [ -d "$HOME/.dotfiles" ]; then
    export DOTFILES_HOME="$HOME/.dotfiles"
    if [ -f "$DOTFILES_HOME/shell/all" ]; then
        . "$DOTFILES_HOME/shell/all"
    fi
fi

cmd="$1"
kind="$(type -t -- "$cmd" || true)"

case "$kind" in
    function|builtin|keyword)
        "$@"
        ;;
    file)
        exec "$@"
        ;;
    *)
        echo "Command not found after shell initialization: $cmd" >&2
        exit 127
        ;;
esac
' bash "${argv[@]}"
