#!/usr/bin/env bash
# monitor-lid-validator.sh — Align monitor layout with lid state at startup.
#
# Called once via exec-once. Reads lid state from ACPI and settings.conf
# from the persisted config file. If they disagree, repositions all
# monitors and updates the persisted state.
#
# Layouts:
#   lid open  → eDP-1 enabled at (4920,420), externals at y=420
#   lid closed → eDP-1 disabled,              externals at y=0

SETTINGS="$HOME/.config/hypr/settings.conf"

# ----- wait for hyprctl -------------------------------------------------

# exec-once fires early — hyprctl socket may not be ready yet.
wait_hyprctl() {
  for i in $(seq 1 60); do
    hyprctl monitors >/dev/null 2>&1 && return 0
    sleep 0.5
  done
  return 1
}
wait_hyprctl || exit 0  # give up silently after 30s

# ----- detect state ----------------------------------------------------

LID_STATE=$(grep -o 'open\|closed' /proc/acpi/button/lid/LID*/state 2>/dev/null || echo "open")
CURRENT=$(grep -o '[01]' "$SETTINGS" 2>/dev/null || echo "1")

# ----- helpers -------------------------------------------------------

move_to_y420() {
  hyprctl keyword monitor "eDP-1,preferred,4920x420,1"
  hyprctl keyword monitor "desc:AOC 24P1W1 OTNQ4HA000101,1920x1080@60,0x420,1,transform,1"
  hyprctl keyword monitor "desc:Lenovo Group Limited LEN G24-10 U5B4GWF1,1920x1080@60,1080x420,1"
  hyprctl keyword monitor "desc:AOC 2470W GGZM3HA438259,1920x1080@60,3000x420,1"
}

move_to_y0() {
  hyprctl keyword monitor "eDP-1,disable"
  hyprctl keyword monitor "desc:AOC 24P1W1 OTNQ4HA000101,1920x1080@60,0x0,1,transform,1"
  hyprctl keyword monitor "desc:Lenovo Group Limited LEN G24-10 U5B4GWF1,1920x1080@60,1080x0,1"
  hyprctl keyword monitor "desc:AOC 2470W GGZM3HA438259,1920x1080@60,3000x0,1"
}

persist()   { printf '$ENABLE_LAPTOP = %s\n' "$1" > "$SETTINGS"; }

# ----- main ----------------------------------------------------------

case "$LID_STATE" in
  closed)
    if [ "$CURRENT" != "0" ]; then
      persist 0
      move_to_y0
    fi
    ;;
  *)
    if [ "$CURRENT" != "1" ]; then
      persist 1
      move_to_y420
    fi
    ;;
esac
