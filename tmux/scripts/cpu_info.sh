#!/usr/bin/env bash
# A part of tmux config, see ~/.tmux/tmux.conf
# Configures tmux status bar in the bottom with some batteries included
# This script is adopted from https://github.com/dracula/tmux/blob/master/scripts/cpu_info.sh

set -e
set -o pipefail

if [ `uname` == "Darwin" ]; then
  # Sum of user + sys CPU usage
  # https://stackoverflow.com/questions/30855440/how-to-get-cpu-utilization-in-in-terminal-mac
  # On MacOS: top is CPU-greedy in the first run,
  # so we stream in a loop (so that component-cpu can print line-by-line)
  top -l 60 -s 2 | grep --line-buffered -E "^CPU" | while read line; do
      echo "$line" | awk '{ printf "%.2f\n", $3 + $5 }'
  done
else
  # https://unix.stackexchange.com/questions/69185/getting-cpu-usage-same-every-time/
  cat <(grep 'cpu ' /proc/stat) <(sleep 1 && grep 'cpu ' /proc/stat) | \
    awk -v RS="" '{printf "%.2f\n", ($13-$2+$15-$4)*100/($13-$2+$15-$4+$16-$5) "%"}'
fi
