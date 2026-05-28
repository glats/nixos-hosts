#!/usr/bin/env bash
# kb-toggle.sh — Toggle keyboard layout between ES and LatAm on t14.
#
# Usage: kb-toggle.sh
# Reads current layout from hyprctl and cycles to the next one.
#
# Assumes omarchy has set up xkb layout groups. This script
# wraps hyprctl to do the actual switch.

set -euo pipefail

# The layout groups defined in input.kb_layout = "es,latam".
LAYOUTS="es,latam"

# Get current keyboard group. hyprland uses group 0 for first layout.
CURRENT_GROUP=$(hyprctl keyboard-layout groups 2>/dev/null | grep -oE '[0-9]+' | head -1 || echo 0)

# Toggle between group 0 (es) and group 1 (latam)
NEXT_GROUP=$(( (CURRENT_GROUP + 1) % 2 ))
hyprctl switchxkblayout keyboard group "$NEXT_GROUP" 2>/dev/null || true