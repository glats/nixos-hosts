# T14 Hypridle configuration.
#
# This module overrides specific upstream omarchy hypridle settings
# with the user's t14-specific values.
#
# - lock_cmd: omarchy-system-lock (same as upstream, not overridden).
# - before_sleep_cmd: omarchy-system-lock with OMARCHY_LOCK_ONLY=true
#   (overrides upstream's loginctl lock-session).  This prevents the
#   1password unlock dialog from re-prompting on resume.
# - after_sleep_cmd: 1s sleep then omarchy-system-wake (overrides
#   upstream's `hyprctl dispatch dpms on`).  Gives PAM time to release
#   the session before the display comes back.
# - inhibit_sleep: 3s (same as upstream, not overridden).
# - listener @150s: launch the screensaver if hyprlock is not running
#   (matches upstream).
# - listener @152s: lock the system on idle (matches upstream's lock
#   listener timing — upstream uses 151s, t14 uses 152s to give the
#   screensaver 2s to start).
# - The upstream dpms-off @ 330s listener is intentionally dropped on
#   t14 — the user prefers the display to stay on while locked.
#
# Merge semantics: `services.hypridle.settings` is an attrset whose
# sub-keys union.  `general.{before,after}_sleep_cmd` are scalar
# strings, so lib.mkForce wins.  `listener` is a list — HM's
# `toHyprconf` generator (and Nix's attrset merge) CONCATENATE
# lists from multiple modules.  To get REPLACEMENT instead of
# concatenation, we use lib.mkForce on the entire listener attribute.
{ lib, ... }:

{
  services.hypridle = {
    enable = true;
    settings = {
      general = {
        before_sleep_cmd = lib.mkForce "OMARCHY_LOCK_ONLY=true omarchy-system-lock";
        after_sleep_cmd = lib.mkForce "sleep 1 && omarchy-system-wake";
      };

      # Replace upstream's 3 listeners with the user's 2 listeners.
      # The upstream dpms-off @ 330s listener is dropped because the
      # user prefers the display to stay on while locked.
      # lib.mkForce on the list ensures replacement, not concatenation.
      listener = lib.mkForce [
        {
          timeout = 150;
          on-timeout = "pidof hyprlock || omarchy-launch-screensaver";
        }
        {
          # Lock system after 5 minutes (screensaver resets idle
          # timer, so 2s margin is needed to let the screensaver
          # actually start first).
          timeout = 152;
          on-timeout = "omarchy-system-lock";
          on-resume = "omarchy-system-wake";
        }
      ];
    };
  };
}
