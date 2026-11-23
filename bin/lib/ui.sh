# Output in the style of bin/version: a ● header naming the command, then one indented line per event.
# Colors only on a terminal, never with NO_COLOR. UI_NESTED=1 drops the header (install running vscode-theme).

UI_ACCENT='38;5;74'

if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
    UI_BOLD=$'\e[1;'"${UI_ACCENT}m" UI_AREA=$'\e['"${UI_ACCENT}m" UI_ITALIC=$'\e[3m' UI_DIM=$'\e[2m' UI_GREEN=$'\e[32m' UI_YELLOW=$'\e[33m' UI_RED=$'\e[31m' UI_RESET=$'\e[0m'
else
    UI_BOLD='' UI_AREA='' UI_ITALIC='' UI_DIM='' UI_GREEN='' UI_YELLOW='' UI_RED='' UI_RESET=''
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
        changelog "$dir" "$before" "$after"
    fi
}

CHANGELOG_MAX=20

# What a pull brought in: files and lines changed, then "hash subject" per commit, newest first.
changelog() {
    local dir="$1" range="$2..$3" n stat

    stat="$(git -C "$dir" diff --shortstat "$2" "$3" | awk '{
        a = 0; d = 0
        for (i = 2; i <= NF; i++) { if ($i ~ /^insertion/) a = $(i - 1); if ($i ~ /^deletion/) d = $(i - 1) }
        printf "%d file%s changed, +%d −%d", $1, ($1 == 1 ? "" : "s"), a, d
    }')"
    [[ -z "$stat" ]] || note "$stat"
    n="$(git -C "$dir" rev-list --count --no-merges "$range")"
    commit_lines "$dir" -n "$CHANGELOG_MAX" "$range"
    (( n <= CHANGELOG_MAX )) || note "… and $(( n - CHANGELOG_MAX )) more"
}

# "hash area: subject" per commit of git log in $1 (the rest are git log arguments), subjects aligned
# past the longest area. A subject with no "area: " prefix gets an italic "unknown:".
commit_lines() {
    local dir="$1" hash subject area w=0 i re='^([A-Za-z0-9._/-]+(, [A-Za-z0-9._/-]+)*): (.*)$'
    local -a hashes=() areas=() subjects=()
    shift
    while IFS=$'\t' read -r hash subject; do
        if [[ "$subject" =~ $re ]]; then
            area="${BASH_REMATCH[1]}:" subject="${BASH_REMATCH[3]}"
        else
            area="unknown:"
        fi
        hashes+=("$hash") areas+=("$area") subjects+=("$subject")
        (( ${#area} <= w )) || w=${#area}
    done < <(git --no-pager -C "$dir" log --no-merges --format='%h%x09%s' "$@")
    (( ${#hashes[@]} > 0 )) || return 0
    for i in "${!hashes[@]}"; do
        printf '    %s%s%s %s%-*s%s %s\n' "$UI_DIM" "${hashes[i]}" "$UI_RESET" \
            "$([[ "${areas[i]}" == unknown: ]] && echo "$UI_ITALIC" || echo "$UI_AREA")" "$w" "${areas[i]}" "$UI_RESET" "${subjects[i]}"
    done
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
