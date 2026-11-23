# Output in the style of bin/version: a ● header naming the command, then one indented line per event.
# Colors only on a terminal, never with NO_COLOR. UI_NESTED=1 drops the header (install running vscode-theme).

UI_ACCENT='38;5;74'

if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
    UI_BOLD=$'\e[1;'"${UI_ACCENT}m" UI_DIM=$'\e[2m' UI_GREEN=$'\e[32m' UI_YELLOW=$'\e[33m' UI_RED=$'\e[31m' UI_RESET=$'\e[0m'
else
    UI_BOLD='' UI_DIM='' UI_GREEN='' UI_YELLOW='' UI_RED='' UI_RESET=''
fi
if [[ -t 2 && -z "${NO_COLOR:-}" ]]; then
    UI_ERR_RED=$'\e[31m' UI_ERR_RESET=$'\e[0m'
else
    UI_ERR_RED='' UI_ERR_RESET=''
fi

header() {
    [[ -n "${UI_NESTED:-}" ]] || printf '%s●%s %s%s%s\n' "$UI_BOLD" "$UI_RESET" "$UI_BOLD" "$*" "$UI_RESET"
}

ui_mark() {
    printf '  %s%s%s %s\n' "$1" "$2" "$UI_RESET" "$3"
}

ok() { ui_mark "$UI_GREEN" ✓ "$*"; }
reloaded() { ui_mark "$UI_GREEN" ↺ "$*"; }
warn() { ui_mark "$UI_YELLOW" ! "$*"; }
skip() { printf '  %s– %s%s\n' "$UI_DIM" "$*" "$UI_RESET"; }
note() { printf '    %s%s%s\n' "$UI_DIM" "$*" "$UI_RESET"; }
err() { printf '  %s✗%s %s\n' "$UI_ERR_RED" "$UI_ERR_RESET" "$*" >&2; }

# A failed command's own output, indented under the ✗ line.
err_output() {
    [[ -n "$1" ]] && printf '%s\n' "$1" | sed 's/^/    /' >&2
    return 0
}

# "1 commit", "3 commits"
plural() { (( $1 == 1 )) && echo "1 $2" || echo "$1 $2s"; }

# git pull in $1 (extra arguments go to git pull), as one line: commits pulled with old → new hash, or up to date.
git_pull_line() {
    local dir="$1" before after out upstream
    shift

    before="$(git -C "$dir" rev-parse --short HEAD)"
    if ! out="$(GIT_TERMINAL_PROMPT=0 git -C "$dir" pull --quiet "$@" 2>&1 < /dev/null)"; then
        err "git pull failed"
        err_output "$out"
        return 1
    fi
    after="$(git -C "$dir" rev-parse --short HEAD)"
    upstream="$(git -C "$dir" rev-parse --abbrev-ref '@{u}' 2>/dev/null || echo upstream)"
    if [[ "$before" == "$after" ]]; then
        ok "up to date with $upstream"
    else
        ok "pulled $(plural "$(git -C "$dir" rev-list --count "$before..$after")" commit)  $UI_DIM$before → $after$UI_RESET"
    fi
}

# git push in $1 (extra arguments go to git push), as one line.
git_push_line() {
    local dir="$1" upstream="" ahead="" out
    shift

    [[ -z "$(git -C "$dir" status --porcelain)" ]] || warn "uncommitted changes stay behind; commit them to push them"
    if (( $# == 0 )) && upstream="$(git -C "$dir" rev-parse --abbrev-ref '@{u}' 2>/dev/null)"; then
        ahead="$(git -C "$dir" rev-list --count "$upstream..HEAD")"
    fi
    if ! out="$(GIT_TERMINAL_PROMPT=0 git -C "$dir" push --quiet "$@" 2>&1 < /dev/null)"; then
        err "git push failed"
        err_output "$out"
        return 1
    fi
    if [[ -z "$upstream" ]]; then
        ok "pushed"
    elif (( ahead == 0 )); then
        ok "nothing to push; up to date with $upstream"
    else
        ok "pushed $(plural "$ahead" commit) to $upstream  $UI_DIM$(git -C "$dir" rev-parse --short HEAD)$UI_RESET"
    fi
}
