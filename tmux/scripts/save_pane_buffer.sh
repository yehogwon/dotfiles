#!/bin/bash

pane_id=$1
pane_title=$(tmux display-message -p -t $pane_id "#{pane_title}")
timestamp=$(date +%Y%m%d_%H%M%S)
output_file="pane_${pane_title}_${timestamp}.log"

tmux capture-pane -pJ -S - -t "$pane_id" > $output_file
