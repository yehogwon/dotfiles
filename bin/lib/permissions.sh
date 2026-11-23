# Apply the modes listed in the repo's .permissions manifest ("<mode> <repo path>" per line). Needs ui.sh.

contains_parent_traversal() {
    local path="$1"

    [[ "/$path/" == *"/../"* ]]
}

is_valid_permission_mode() {
    local mode="$1"

    [[ "$mode" =~ ^[0-7]{3,4}$ ]]
}

is_within_dir() {
    local path="$1"
    local root_dir="$2"

    [[ "$path" == "$root_dir" || "$path" == "$root_dir"/* ]]
}

resolve_permissions_repo_path() {
    local repo_root="$1"
    local path="$2"

    [[ "$path" != /* ]] || return 1
    contains_parent_traversal "$path" && return 1

    printf '%s\n' "$repo_root/$path"
}

file_mode() {
    stat -c %a "$1" 2>/dev/null || stat -f %Lp "$1"
}

enforce_permissions_manifest() {
    local repo_root="$1"
    local manifest_name="${2:-.permissions}"
    local manifest_path="$repo_root/$manifest_name"
    local repo_root_real
    local line=""
    local line_number=0
    local entry_mode
    local entry_path
    local extra
    local target_path
    local target_path_real
    local checked=0
    local fixed=0

    if [[ ! -f "$manifest_path" ]]; then
        skip "permissions manifest not found at $manifest_path"
        return 0
    fi

    repo_root_real="$(realpath "$repo_root")"

    while IFS= read -r line || [[ -n "$line" ]]; do
        line_number=$((line_number + 1))

        [[ "$line" =~ ^[[:space:]]*$ ]] && continue
        [[ "$line" =~ ^[[:space:]]*# ]] && continue

        read -r entry_mode entry_path extra <<< "$line"

        if [[ -n "$extra" || -z "$entry_mode" || -z "$entry_path" ]]; then
            err "invalid permissions entry at $manifest_path:$line_number"
            exit 1
        fi

        if ! is_valid_permission_mode "$entry_mode"; then
            err "invalid mode at $manifest_path:$line_number: $entry_mode"
            exit 1
        fi

        target_path="$(resolve_permissions_repo_path "$repo_root" "$entry_path" || true)"
        if [[ -z "$target_path" ]]; then
            err "invalid managed path at $manifest_path:$line_number: $entry_path"
            exit 1
        fi

        if [[ ! -e "$target_path" ]]; then
            err "managed path not found at $manifest_path:$line_number: $entry_path"
            exit 1
        fi

        if [[ -L "$target_path" ]]; then
            err "symlink targets are not allowed at $manifest_path:$line_number: $entry_path"
            exit 1
        fi

        if [[ ! -f "$target_path" && ! -d "$target_path" ]]; then
            err "managed path must be a regular file or directory at $manifest_path:$line_number: $entry_path"
            exit 1
        fi

        target_path_real="$(realpath "$target_path")"
        if ! is_within_dir "$target_path_real" "$repo_root_real"; then
            err "managed path escapes DOTFILES_DIR at $manifest_path:$line_number: $entry_path"
            exit 1
        fi

        checked=$((checked + 1))
        if (( 8#$(file_mode "$target_path") != 8#$entry_mode )); then
            chmod "$entry_mode" "$target_path"
            ok "set $entry_mode on $entry_path"
            fixed=$((fixed + 1))
        fi
    done < "$manifest_path"

    ok "permissions: $(plural "$checked" path) checked, $fixed fixed"
}
