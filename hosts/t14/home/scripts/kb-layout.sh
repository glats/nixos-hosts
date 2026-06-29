#!/usr/bin/env bash
# kb-layout.sh — Show or set keyboard layout on t14.
#
# Usage:
#   kb-layout.sh          — print current layout name and exit
#   kb-layout.sh <layout> — set keyboard to the named layout
#
# Layout names must match those in input.kb_layout (es, latam).

set -euo pipefail

ACTION="${1:-}"

find_device() {
  hyprctl devices 2>/dev/null | awk '
    /Keyboard at/               { kb_main=0; dev="" }
    /^[[:space:]]+[-a-z0-9]+$/  { dev=$0; sub(/^[[:space:]]+/, "", dev) }
    /main: yes/ && dev != ""    { kb_main=1; print dev; exit }
  '
}

get_current() {
  hyprctl devices 2>/dev/null | awk '
    /Keyboard at/               { kb_main=0; dev="" }
    /^[[:space:]]+[-a-z0-9]+$/  { dev=$0; sub(/^[[:space:]]+/, "", dev) }
    /active layout index/       { last_idx=$NF }
    /main: yes/ && dev != ""    { kb_main=1; main_idx=last_idx }
    END {
      if (main_idx == "1") print "latam"; else print "es"
    }
  '
}

set_layout() {
  local target="$1"
  local group_index

  case "$target" in
    es)    group_index=0 ;;
    latam) group_index=1 ;;
    *)
      echo "kb-layout.sh: unknown layout '$target' (expected: es, latam)" >&2
      return 1
      ;;
  esac

  local device
  device=$(find_device)

  hyprctl switchxkblayout "$device" "$group_index" 2>/dev/null || true
}

if [[ -n "$ACTION" ]]; then
  set_layout "$ACTION"
else
  get_current
fi
