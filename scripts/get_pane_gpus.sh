#!/bin/bash

pane_id=$1 # e.g., %1

pane_pid=$(tmux list-panes -F "#{pane_id} #{pane_pid}" | grep "$pane_id" | cut -d ' ' -f2)

if ! child_pids_tmp=$(pgrep -P $pane_pid 2>/dev/null); then
    echo "NoGPU"
    exit 0
fi
# child_pids=$(echo "$child_pids_tmp" | xargs pgrep -P 2>/dev/null | tr '\n' ' ')
child_pids=$(echo "$child_pids_tmp" | tr '\n' ' ')

# Parse nvidia-smi output into arrays
gpu_pids=()
gpu_names=()
gpu_uuids=()

while IFS=, read -r pid gpu_name gpu_uuid; do
    gpu_pids+=("$pid")
    gpu_names+=("$gpu_name")
    gpu_uuids+=("$gpu_uuid")
done < <(nvidia-smi --query-compute-apps=pid,gpu_name,gpu_uuid --format=csv,noheader)

# Find matching GPU UUIDs for child_pids
matching_uuids=()
for pid in $child_pids; do
    for i in "${!gpu_pids[@]}"; do
        if [[ "${gpu_pids[$i]}" == "$pid" ]]; then
            matching_uuids+=("${gpu_uuids[$i]}")
        fi
    done
done

# Get GPU indices from matching UUIDs
gpu_indices=()
for uuid in "${matching_uuids[@]}"; do
    index=$(nvidia-smi -L | grep $uuid | awk '{print $2}' | tr -d ':')
    gpu_indices+=("$index")
done

gpu_indices=($(echo "${gpu_indices[@]}" | tr ' ' '\n' | sort -n | uniq | tr '\n' ' '))

# if gpu_indices is empty, say no gpu
if [ ${#gpu_indices[@]} -eq 0 ]; then
    echo "NoGPU"
else
    echo "CUDA:$(IFS=,; echo "${gpu_indices[*]}")"
fi
