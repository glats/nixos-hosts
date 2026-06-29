#!/usr/bin/env bash
# monitor-lid-validator.sh — Align monitor layout with lid state at startup.
#
# Called via systemd oneshot service after graphical-session.target.
# Always applies the correct layout — idempotent (hyprctl keyword is no-op
# if monitors are already at the target position).

SETTINGS="$HOME/.config/hypr/settings.conf"

# ----- ensure hyprctl can find the compositor ---------------------------

if [ -z "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then
  export HYPRLAND_INSTANCE_SIGNATURE=$(ls -t "$XDG_RUNTIME_DIR/hypr/" 2>/dev/null | head -1)
fi

# ----- detect state ----------------------------------------------------

LID_STATE=$(grep -o 'open\|closed' /proc/acpi/button/lid/LID*/state 2>/dev/null || echo "open")

# ----- helpers ---------------------------------------------------------

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

persist() {
  if [ "$1" = "1" ]; then
    printf '$ENABLE_LAPTOP = 1\n' > "$SETTINGS"
  else
    printf '$ENABLE_LAPTOP =\n' > "$SETTINGS"
  fi
}

# ----- main ------------------------------------------------------------

case "$LID_STATE" in
  closed)
    persist 0
    move_to_y0
    ;;
  *)
    persist 1
    move_to_y420
    ;;
esac
