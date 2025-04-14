# shellcheck disable
# Print the variable status of "@cwd_sync_panes"

run_segment() {
    status=$(tmux show-window-options -v synchronize-panes 2>/dev/null)
    if [ "$status" = "on" ]; then
        echo "panes synced"
    fi
	return 0
}
