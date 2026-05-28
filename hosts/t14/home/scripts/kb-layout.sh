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

get_current() {
  # hyprland keyboard-layout command outputs current layout state.
  # Format: "keyboard: es | group: 0" — we extract the layout name.
  hyprctl keyboard-layout 2>/dev/null | \
  grep -oE 'keyboard: [a-z]+' | awk '{print $2}' || echo "es"
}

set_layout() {
  local target="$1"
  # Find the group index for the target layout
  local group_index
  case "$target" in
    es) group_index=0 ;;
    latam) group_index=1 ;;
    *)
      echo "kb-layout.sh: unknown layout '$target' (expected: es, latam)" >&2
      return 1
      ;;
  esac
  hyprctl switchxkblayout keyboard group "$group_index" 2>/dev/null || true
}

if [[ -n "$ACTION" ]]; then
  set_layout "$ACTION"
else
  get_current
fi