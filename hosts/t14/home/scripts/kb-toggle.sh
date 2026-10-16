#!/usr/bin/env bash

DEBOUNCE_FILE="/tmp/kb-toggle.last"
NOW=$(date +%s%N)

if [[ -f "$DEBOUNCE_FILE" ]]; then
  LAST=$(cat "$DEBOUNCE_FILE")
  ELAPSED_MS=$(( (NOW - LAST) / 1000000 ))
  if (( ELAPSED_MS < 500 )); then
    exit 0
  fi
fi
echo "$NOW" > "$DEBOUNCE_FILE"

DEVICE=$(hyprctl devices 2>/dev/null | awk '
  /Keyboard at/               { kb_main=0; dev="" }
  /^[[:space:]]+[-a-z0-9]+$/  { dev=$0; sub(/^[[:space:]]+/, "", dev) }
  /main: yes/ && dev != ""    { kb_main=1; print dev; exit }
')

CURRENT=$(hyprctl devices 2>/dev/null | awk -v dev="$DEVICE" '
  /Keyboard at/               { in_block=0; block_dev="" }
  /^[[:space:]]+[-a-z0-9]+$/  { block_dev=$0; sub(/^[[:space:]]+/, "", block_dev) }
  block_dev == dev            { in_block=1 }
  in_block && /active layout index/ { print $NF; exit }
')

NEXT=$(( (${CURRENT:-0} + 1) % 2 ))
hyprctl switchxkblayout "$DEVICE" "$NEXT" 2>/dev/null
