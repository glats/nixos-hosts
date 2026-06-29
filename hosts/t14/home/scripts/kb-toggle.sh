#!/usr/bin/env bash
# kb-toggle.sh — Toggle keyboard layout between ES and LatAm on t14.
#
# Usage: kb-toggle.sh
# Finds the main keyboard device and toggles between
# layout index 0 (es) and 1 (latam).

set -euo pipefail

# Find the main keyboard device (marked "main: yes")
DEVICE=$(hyprctl devices 2>/dev/null | awk '
  /Keyboard at/               { kb_main=0; dev="" }
  /^[[:space:]]+[-a-z0-9]+$/  { dev=$0; sub(/^[[:space:]]+/, "", dev) }
  /main: yes/ && dev != ""    { kb_main=1; print dev; exit }
')

# Get current layout index from that device
CURRENT=$(hyprctl devices 2>/dev/null | awk -v dev="$DEVICE" '
  /Keyboard at/               { in_block=0; block_dev="" }
  /^[[:space:]]+[-a-z0-9]+$/  { block_dev=$0; sub(/^[[:space:]]+/, "", block_dev) }
  block_dev == dev            { in_block=1 }
  in_block && /active layout index/ { print $NF; exit }
')

# Toggle: 0 -> 1, 1 -> 0
NEXT=$(( (${CURRENT:-0} + 1) % 2 ))
hyprctl switchxkblayout "$DEVICE" "$NEXT" 2>/dev/null || true
