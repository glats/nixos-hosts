#!/usr/bin/env bash
# monitor-hotplug-handler.sh — T14 dynamic monitor hotplug handler.
#
# Called once on session start (see hosts/t14/home/hypr/autostart.nix) and
# runs as a foreground watcher.  Detects external monitors on the
# ThinkPad dock (DP-3/4/5) and toggles between laptop-only and
# multi-monitor layouts.  Also switches the keyboard layout to "es"
# when an external monitor is present (latam stays for laptop-only).
#
# The script is intentionally idempotent: it does not call
# omarchy-hyprland-restart; instead it uses hyprctl dispatch to apply
# monitor changes in place.  This avoids the brief flash from a
# compositor restart every time the user docks or undocks.
#
# REQ-005: hot-plug detection and keyboard layout switching.
set -euo pipefail

# Settle time (seconds) for display hardware to be detected after a
# hotplug event.  2s covers most docks; longer values risk showing the
# wrong layout to the user.
SETTLE=2

# Polling interval (seconds).  5s feels responsive without spamming
# hyprctl.  Hyprland's own monitor-watch handles edge-triggered events;
# this script is the periodic safety net.
POLL=5

# Internal panel name on the T14 AMD Gen 4.
BUILTIN="DP-2"

log() {
  printf '[monitor-hotplug-handler] %s\n' "$*" >&2
}

log "Starting monitor hotplug handler (PID $$)"

# Apply a layout: enable external monitors, disable internal panel.
apply_external_layout() {
  local ext_count="$1"
  log "External monitor(s) detected ($ext_count); applying external layout"
  # Enable every non-builtin monitor, scale 1, preferred mode.
  for m in DP-3 DP-4 DP-5 HDMI-A-1; do
    if hyprctl monitors -j 2>/dev/null | jq -e --arg m "$m" '.monitors[] | select(.name == $m)' >/dev/null 2>&1; then
      hyprctl dispatch exec "hyprctl keyword monitor \"$m,preferred,auto,1\"" >/dev/null 2>&1 || true
    fi
  done
  # Disable the internal panel.
  hyprctl dispatch exec "hyprctl keyword monitor \"$BUILTIN,disable\"" >/dev/null 2>&1 || true
  # Switch to es layout when docked (external keyboard convention).
  kb-layout.sh es 2>/dev/null || true
  log "Applied external layout (es layout active)"
}

# Apply a layout: laptop-only — internal panel active, others disabled.
apply_internal_layout() {
  log "No external monitor; ensuring internal panel is on"
  hyprctl dispatch exec "hyprctl keyword monitor \"$BUILTIN,preferred,auto,1\"" >/dev/null 2>&1 || true
  # Disable any external output that is still around.
  for m in DP-3 DP-4 DP-5 HDMI-A-1; do
    if hyprctl monitors -j 2>/dev/null | jq -e --arg m "$m" '.monitors[] | select(.name == $m and .disabled == false)' >/dev/null 2>&1; then
      hyprctl dispatch exec "hyprctl keyword monitor \"$m,disable\"" >/dev/null 2>&1 || true
    fi
  done
  # Switch to latam layout for the laptop keyboard.
  kb-layout.sh latam 2>/dev/null || true
  log "Applied internal layout (latam layout active)"
}

LAST_STATE=""

while true; do
  sleep "$SETTLE"

  # Query connected monitors; jq filters out the built-in panel.
  EXTERNAL_COUNT=$(hyprctl monitors -j 2>/dev/null | \
    jq --arg b "$BUILTIN" '[.monitors[] | select(.name != $b and .name != "DSI-1")] | length' 2>/dev/null || echo 0)

  STATE=$([ "$EXTERNAL_COUNT" -gt 0 ] && echo "external" || echo "internal")

  # Idempotent: only re-apply when state changes.
  if [[ "$STATE" != "$LAST_STATE" ]]; then
    if [[ "$STATE" == "external" ]]; then
      apply_external_layout "$EXTERNAL_COUNT"
    else
      apply_internal_layout
    fi
    LAST_STATE="$STATE"
  fi

  sleep "$POLL"
done
