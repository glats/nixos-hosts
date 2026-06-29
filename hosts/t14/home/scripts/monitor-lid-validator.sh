#!/usr/bin/env bash
# monitor-lid-validator.sh
exec 2>/tmp/monitor-lid-validator.log
set -x
echo "=== start $(date) HIS=${HYPRLAND_INSTANCE_SIGNATURE:-unset} ==="

SETTINGS="$HOME/.config/hypr/settings.conf"
echo "HOME=$HOME XDG_RUNTIME_DIR=$XDG_RUNTIME_DIR HIS=${HYPRLAND_INSTANCE_SIGNATURE:-unset}"

# ----- ensure hyprctl can find the compositor ---------------------------

if [ -z "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then
  export HYPRLAND_INSTANCE_SIGNATURE=$(ls -t "$XDG_RUNTIME_DIR/hypr/" 2>/dev/null | head -1)
fi

# ----- detect state ----------------------------------------------------

LID_STATE=$(grep -o 'open\|closed' /proc/acpi/button/lid/LID*/state 2>/dev/null || echo "open")
CURRENT=$(grep -o '[01]' "$SETTINGS" 2>/dev/null || echo "1")

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

persist() { printf '$ENABLE_LAPTOP = %s\n' "$1" > "$SETTINGS"; }

# ----- main ------------------------------------------------------------

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
