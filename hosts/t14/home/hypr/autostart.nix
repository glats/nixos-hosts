# T14 Hyprland autostart — t14-specific exec-once entries.
# Extends (not replaces) omarchy's autostart list.
{ ... }:

{
  wayland.windowManager.hyprland.settings = {
    exec-once = [
      # Start the monitor hotplug watcher on login
      "uwsm-app -- monitor-hotplug-handler.sh &"
    ];
  };
}