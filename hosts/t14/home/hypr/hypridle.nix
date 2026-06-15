# T14 Hypridle — manual management (no systemd service).
#
# Omarchy original (Arch) manages hypridle manually via exec-once.
# The omarchy-nix module enables services.hypridle which creates a
# systemd service with Restart=always. This defeats omarchy-toggle-idle
# which uses pkill to stop hypridle.
#
# Fix: Disable systemd service, generate config manually, start via exec-once.
#
# Listener notes:
# - listener @150s: launch the screensaver if hyprlock is not running.
# - listener @152s: lock the system on idle (5min screensaver + 2s margin).
# - The upstream dpms-off @ 330s listener is intentionally dropped on
#   t14 — the user prefers the display to stay on while locked.
{ lib, ... }:

{
  # Disable Home Manager's systemd service for hypridle.
  # Omarchy manages hypridle manually via exec-once (original omarchy behavior).
  services.hypridle.enable = lib.mkForce false;

  # Generate the hypridle config file manually since HM only creates it when enable=true.
  # Each listener needs its own [listener] section — hypridle.conf(5) requires this.
  # Cannot use lib.generators.toINI because it deduplicates section names.
  xdg.configFile."hypr/hypridle.conf".text = ''
    [general]
    lock_cmd=omarchy-system-lock
    before_sleep_cmd=OMARCHY_LOCK_ONLY=true omarchy-system-lock
    after_sleep_cmd=sleep 1 && omarchy-system-wake
    ignore_dbus_inhibit=false
    inhibit_sleep=3

    [listener]
    timeout=150
    on-timeout=pidof hyprlock || omarchy-launch-screensaver

    [listener]
    timeout=152
    on-timeout=omarchy-system-lock
    on-resume=omarchy-system-wake
  '';
}
