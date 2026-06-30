#!/usr/bin/env bash
# monitor-lid-validator.sh — Align monitor layout with lid state.
#
# --daemon      Run once, then poll every 2s and re-apply on changes.
# --apply-once  Apply once and exit (called by daemon on hotplug).
# (no args)     Apply once and exit (for systemd oneshot restart).

SETTINGS="$HOME/.config/hypr/settings.conf"
HIS_DIR="$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE"

# ----- ensure hyprctl can find the compositor ---------------------------

if [ -z "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then
  export HYPRLAND_INSTANCE_SIGNATURE=$(ls -t "$XDG_RUNTIME_DIR/hypr/" 2>/dev/null | head -1)
fi

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

apply() {
  LID_STATE=$(grep -o 'open\|closed' /proc/acpi/button/lid/LID*/state 2>/dev/null || echo "open")
  case "$LID_STATE" in
    closed) persist 0; move_to_y0 ;;
    *)      persist 1; move_to_y420 ;;
  esac
}

monitor_snapshot() {
  hyprctl monitors -j 2>/dev/null | grep '"name"' | sort
}

# ----- main ------------------------------------------------------------

case "${1:-}" in
  --apply-once) apply; exit 0 ;;
  --daemon)
    apply
    LAST=$(monitor_snapshot)
    while true; do
      sleep 2
      NOW=$(monitor_snapshot)
      if [ "$NOW" != "$LAST" ]; then
        apply
        LAST="$NOW"
      fi
    done
    ;;
  *) apply; exit 0 ;;
esac
