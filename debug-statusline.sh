#!/bin/bash
input=$(cat)
echo "$input" > /tmp/statusline-debug.json
echo "DEBUG: $input" | jq '.context_window' > /tmp/statusline-context.json
time=$(date +%H:%M:%S)
echo "$time"
