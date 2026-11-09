# Recorded symlinks for apps without includes; replaced files are backed up and restored on unlink.

DOTFILES_STATE="${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles"
LINKS_DB="$DOTFILES_STATE/links"            # area<TAB>link<TAB>target<TAB>backup
UNPLUGGED_DB="$DOTFILES_STATE/unplugged"    # one area per line
LINK_AREAS="claude herdr-app herdr-core"

# area<TAB>repo path<TAB>link for every link this machine should have
dotfiles_links() {
    local cfg="${XDG_CONFIG_HOME:-$HOME/.config}"
    local app="$HOME/.config/herdr-app"
    local f

    if [[ -d "$HOME/.claude" ]]; then
        if command -v hc >/dev/null 2>&1 || [[ -x "$HOME/.local/bin/hc" ]]; then
            want claude claude/skills/herdr-core/SKILL.md "$HOME/.claude/skills/herdr-core/SKILL.md"
        fi
        if [[ -d "$app" ]]; then
            want claude claude/skills/herdr-app/SKILL.md "$HOME/.claude/skills/herdr-app/SKILL.md"
        fi
    fi

    want herdr-core herdr/core/config.toml "$cfg/herdr-core/config.toml"
    for f in "$DOTFILES_DIR"/herdr/core/templates/*.md; do
        [[ -f "$f" ]] || continue
        valid_template "$f" || continue
        want herdr-core "herdr/core/templates/${f##*/}" "$cfg/herdr-core/templates/${f##*/}"
    done

    if [[ -d "$app" ]]; then
        want herdr-app herdr/app/keys.json "$app/keys.json"
        for f in "$DOTFILES_DIR"/herdr/app/layouts/*.json; do
            [[ -f "$f" ]] && want herdr-app "herdr/app/layouts/${f##*/}" "$app/layouts/${f##*/}"
        done
        for f in "$DOTFILES_DIR"/herdr/app/mods/*/; do
            f="${f%/}"
            [[ -d "$f" ]] && want herdr-app "herdr/app/mods/${f##*/}" "$app/mods/${f##*/}"
        done
    fi

    return 0
}

want() {
    printf '%s\t%s\t%s\n' "$1" "$2" "$3"
}

valid_template() {
    local file="$1"

    if [[ "$(head -n 1 "$file")" == "---" ]] &&
        awk 'NR > 1 && $0 == "---" {closed = 1; exit} NR > 1 && /^command:/ {cmd = 1} END {exit !(closed && cmd)}' "$file"; then
        return 0
    fi

    log "[warn] ${file#"$DOTFILES_DIR"/} needs frontmatter with a command: line; not linked" >&2
    return 1
}

count_links() {
    if [[ -f "$LINKS_DB" ]]; then
        awk 'END {print NR}' "$LINKS_DB"
    else
        echo 0
    fi
}

is_unplugged() {
    grep -qxF "$1" "$UNPLUGGED_DB" 2>/dev/null
}

tilde() {
    case "$1" in
        "$HOME"/*) printf '~/%s\n' "${1#"$HOME"/}" ;;
        *) printf '%s\n' "$1" ;;
    esac
}

db_get() {
    [[ -f "$LINKS_DB" ]] || return 0
    awk -F '\t' -v link="$1" '$2 == link' "$LINKS_DB"
}

db_put() {
    local tmp

    mkdir -p "$DOTFILES_STATE"
    tmp="$(mktemp)"
    [[ -f "$LINKS_DB" ]] && awk -F '\t' -v link="$2" '$2 != link' "$LINKS_DB" > "$tmp"
    printf '%s\t%s\t%s\t%s\n' "$1" "$2" "$3" "$4" >> "$tmp"
    mv "$tmp" "$LINKS_DB"
}

db_del() {
    local tmp

    [[ -f "$LINKS_DB" ]] || return 0
    tmp="$(mktemp)"
    awk -F '\t' -v link="$1" '$2 != link' "$LINKS_DB" > "$tmp"
    mv "$tmp" "$LINKS_DB"
}

link_one() {
    local area="$1" target="$2" link="$3"
    local record old_target="" backup=""

    record="$(db_get "$link")"
    if [[ -n "$record" ]]; then
        IFS=$'\t' read -r _ _ old_target backup <<< "$record"
    fi

    if [[ -L "$link" && "$(readlink "$link")" == "$target" ]]; then
        [[ "$record" == "$area"$'\t'"$link"$'\t'"$target"$'\t'"$backup" ]] || db_put "$area" "$link" "$target" "$backup"
        return 0
    fi

    if [[ -n "$record" ]]; then
        if [[ -L "$link" && "$(readlink "$link")" == "$old_target" ]]; then
            rm -f "$link"    # ours, from a checkout that moved
        elif [[ -e "$link" || -L "$link" ]]; then
            log "[warn] $(tilde "$link") was replaced by a local copy; left alone (delete it to link again)"
            return 0
        fi
    elif [[ -e "$link" || -L "$link" ]]; then
        backup="$DOTFILES_STATE/backups/$LINK_STAMP/$(tilde "$link" | sed 's|^~/||; s|^/||')"
        mkdir -p "$(dirname "$backup")"
        mv "$link" "$backup"
        log "[info] moved $(tilde "$link") to $(tilde "$backup")"
    fi

    mkdir -p "$(dirname "$link")"
    ln -s "$target" "$link"
    db_put "$area" "$link" "$target" "$backup"
    log "[ok] linked $(tilde "$link")"
}

unlink_one() {
    local link="$1" target="$2" backup="$3"
    local dir

    if [[ -L "$link" && "$(readlink "$link")" == "$target" ]]; then
        rm -f "$link"
    elif [[ -e "$link" || -L "$link" ]]; then
        log "[warn] $(tilde "$link") is no longer a dotfiles link; left alone"
        [[ -n "$backup" && -e "$backup" ]] && log "[hint] the file it replaced is at $(tilde "$backup")"
        db_del "$link"
        return 0
    fi

    if [[ -n "$backup" && ( -e "$backup" || -L "$backup" ) ]]; then
        mv "$backup" "$link"
        log "[ok] restored $(tilde "$link")"
        dir="$(dirname "$backup")"
        while [[ "$dir" == "$DOTFILES_STATE/backups/"* ]] && rmdir "$dir" 2>/dev/null; do
            dir="$(dirname "$dir")"
        done
    else
        log "[ok] removed $(tilde "$link")"
        dir="$(dirname "$link")"
        while [[ "$dir" == "$HOME/"* && "$dir" != "$HOME/.config" && "$dir" != "$HOME/.claude" ]] &&
            rmdir "$dir" 2>/dev/null; do
            dir="$(dirname "$dir")"
        done
    fi

    db_del "$link"
}

apply_links() {
    local wanted kept area src link target backup

    step "linking app configs"
    LINK_STAMP="$(date +%y%m%d-%H%M%S)"
    wanted="$(mktemp)"
    kept="$(mktemp)"
    dotfiles_links > "$wanted"

    while IFS=$'\t' read -r area src link; do
        is_unplugged "$area" && continue
        if [[ ! -e "$DOTFILES_DIR/$src" ]]; then
            log "[warn] $src not found; skipping"
            continue
        fi
        link_one "$area" "$DOTFILES_DIR/$src" "$link" < /dev/null
        printf '%s\n' "$link" >> "$kept"
    done < "$wanted"

    if [[ -f "$LINKS_DB" ]]; then
        cp "$LINKS_DB" "$wanted"
        while IFS=$'\t' read -r area link target backup; do
            grep -qxF "$link" "$kept" || unlink_one "$link" "$target" "$backup" < /dev/null
        done < "$wanted"
    fi

    rm -f "$wanted" "$kept"
    log "[ok] $(count_links) links in place"
}

unlink_links() {
    local only="${1:-}" copy area link target backup

    [[ -s "$LINKS_DB" ]] || return 0
    copy="$(mktemp)"
    cp "$LINKS_DB" "$copy"
    while IFS=$'\t' read -r area link target backup; do
        [[ -z "$only" || "$area" == "$only" ]] || continue
        unlink_one "$link" "$target" "$backup" < /dev/null
    done < "$copy"
    rm -f "$copy"
}
