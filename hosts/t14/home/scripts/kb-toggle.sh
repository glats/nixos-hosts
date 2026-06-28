#!/usr/bin/env bash
# kb-toggle.sh — Toggle keyboard layout between ES and LatAm on t14.
#
# Usage: kb-toggle.sh
# Reads current layout name from hyprctl and toggles to the other one.
#
# Uses the same hyprctl command as kb-layout.sh for consistency.

set -euo pipefail

CURRENT=$(hyprctl keyboard-layout 2>/dev/null | grep -oE 'keyboard: [a-z]+' | awk '{print $2}' || echo "es")

case "$CURRENT" in
  es)   hyprctl switchxkblayout keyboard group 1 2>/dev/null || true ;;
  latam) hyprctl switchxkblayout keyboard group 0 2>/dev/null || true ;;
  *)    hyprctl switchxkblayout keyboard group 1 2>/dev/null || true ;; # default: switch to latam
esac