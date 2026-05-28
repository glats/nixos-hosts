#!/usr/bin/env bash
# monitor-hotplug-handler.sh — T14 monitor hotplug detection and reconfiguration.
#
# Called by hyprland's monitor-watch exec-once (omarchy-hyprland-monitor-watch)
# or triggered manually.  Uses omarchy's monitor management helpers.
#
# Strategy:
#   1. Wait briefly for the display hardware to settle after a plug event.
#   2. Check if any external display is connected via hyprctl.
#   3. If external display detected  → call omarchy-hw-external-monitors.
#   4. If no external display       → call omarchy-hyprland-monitor-internal on.

set -euo pipefail

# Settle time for display hardware to be detected after hotplug (seconds).
SETTLE=2

log() {
  printf '[monitor-hotplug-handler] %s\n' "$*" >&2
}

log "Starting monitor hotplug handler (PID $$)"

# Main loop: check for external monitors every 30 seconds.
# The exec-once starts this script once; it runs in the background.
while true; do
  sleep "$SETTLE"

  # Query connected monitors; external monitors have names like DP-A-1, HDMI-A-1, etc.
  MONITORS=$(hyprctl monitors -j 2>/dev/null || echo '{"monitors":[]}')

  # Count monitors that are not the primary builtin panel (DP-2 on t14)
  EXTERNAL_COUNT=$(printf '%s' "$MONITORS" | \
    jq '[.monitors[] | select(.name != "DP-2" and .name != "DSI-1")] | length' 2>/dev/null || echo 0)

  if (( EXTERNAL_COUNT > 0 )); then
    log "External monitor(s) detected ($EXTERNAL_COUNT); calling omarchy-hw-external-monitors"
    omarchy-hw-external-monitors 2>/dev/null || true
  else
    log "No external monitor; ensuring internal panel is on"
    omarchy-hyprland-monitor-internal on 2>/dev/null || true
  fi

  # Wait before next check
  sleep 30
done