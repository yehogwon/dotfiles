#!/bin/bash

pane_id=$1

pane_pid=$(tmux list-panes -F "#{pane_id} #{pane_pid}" | grep $pane_id | cut -d ' ' -f2)
child_pids=$(pgrep -P $pane_pid | xargs pgrep -P 2>/dev/null | tr '\n' ' ')

# Parse nvidia-smi output into arrays
while IFS=, read -r pid gpu_name gpu_uuid; do
    pids+=("$pid")
    gpu_names+=("$gpu_name")
    gpu_uuids+=("$gpu_uuid")
done < <(nvidia-smi --query-compute-apps=pid,gpu_name,gpu_uuid --format=csv,noheader)

# Find matching GPU UUIDs for child_pids
matching_uuids=()
for pid in $child_pids; do
    for i in "${!pids[@]}"; do
        if [[ "${pids[$i]}" == "$pid" ]]; then
            matching_uuids+=("${gpu_uuids[$i]}")
            break
        fi
    done
done

# Get GPU indices from matching UUIDs
gpu_indices=()
for uuid in "${matching_uuids[@]}"; do
    index=$(nvidia-smi -L | grep $uuid | awk '{print $2}' | tr -d ':')
    gpu_indices+=("$index")
done

# if gpu_indices is empty, say no gpu
if [ ${#gpu_indices[@]} -eq 0 ]; then
    echo "NoGPU"
else
    echo "CUDA:${gpu_indices[@]}"
fi
