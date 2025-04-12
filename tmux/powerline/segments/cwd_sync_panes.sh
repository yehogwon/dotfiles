# shellcheck disable
# Print the variable status of "@cwd_sync_panes"

VARIABLE_NAME="@cwd_sync_panes"

run_segment() {
    status=$(tmux show -wvq ${VARIABLE_NAME} 2>/dev/null)
    if [ "$status" = "on" ]; then
        echo "cwd synced"
    fi
	return 0
}
