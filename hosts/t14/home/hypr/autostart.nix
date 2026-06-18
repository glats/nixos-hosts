# T14 Hyprland autostart — t14-specific exec-once entries.
# Extends (not replaces) omarchy's autostart list.
#
# NOTE on monitor hotplugging: omarchy's own autostart already runs
# `uwsm-app -- omarchy-hyprland-monitor-watch` which forwards
# Hyprland's monitorremoved socket events to
# `omarchy-hyprland-monitor-internal` (toggle laptop display on/off)
# and `omarchy-hyprland-monitor-internal-mirror` (mirroring). Our
# custom `monitor-hotplug-handler.sh` overlapped with that and the
# bare-name invocation failed because the uwsm_app-daemon's PATH
# does not include `~/.local/share/omarchy/bin` (it inherits PATH
# from the systemd user manager, not the user shell). Removed to
# stop the "Error: Command not found: monitor-hotplug-handler.sh"
# mako notifications and let omarchy's watcher own hotplug handling.
{ ... }:

{
  wayland.windowManager.hyprland.settings = {
    exec-once = [
      # Start hypridle manually (matches original omarchy behavior).
      # Disabled systemd service because omarchy scripts expect manual management.
      "uwsm-app -- hypridle"
      # wayvnc — VNC server capturing Wayland screen via wlroots screencopy.
      # Reads address/port/enable_pam from ~/.config/wayvnc/config
      # (no positional args to avoid clobbering config-file settings).
      "uwsm-app -- wayvnc"
    ];
  };
}
