# mouse-wiggle — prevent screen lock on t14 when idle.
#
# Mechanism: move the mouse pointer by 1px every 50 seconds.
# This prevents the display from sleeping due to inactivity while
# the user is e.g. watching a video that lacks idle-inhibition.
#
# systemd user service approach (not exec-once) so it survives
# transient Hyprland restarts and can be managed independently.
{ lib, pkgs, ... }:

let
  script = pkgs.writeScriptBin "mouse-wiggle" ''
    #!/usr/bin/env bash
    # Move mouse by 1 pixel every 50 seconds to inhibit idle lock.
    # Stop automatically when any fullscreen window is detected.

    set -euo pipefail

    INHIBIT_FILE="/run/user/$(id -u)/mouse-wiggle.inhibited"

    inhibit() {
      touch "$INHIBIT_FILE"
    }

    uninhibit() {
      rm -f "$INHIBIT_FILE"
    }

    is_fullscreen() {
      hyprctl activewindow -j 2>/dev/null | \
        jq -r 'select(.fullscreen == true) | "yes"' | grep -q yes
    }

    main() {
      while true; do
        if is_fullscreen; then
          uninhibit
        else
          inhibit
          xdotool mousemove_relative 1 1 2>/dev/null || \
            hyprctl dispatch movecursor 1 1 2>/dev/null || true
        fi
        sleep 50
      done
    }

    main
  '';
in
{
  home.packages = [ script ];

  # Systemd user service so mouse-wiggle starts with the session
  # and survives Hyprland restarts.
  systemd.user.services.mouse-wiggle = {
    Unit = {
      Description = "Mouse wiggle — prevent idle lock during fullscreen media";
      After = [ "graphical-session-pre.target" ];
      PartOf = [ "graphical-session.target" ];
    };
    Service = {
      Type = "simple";
      ExecStart = "${script}/bin/mouse-wiggle";
      Restart = "on-failure";
    };
    Install = {
      WantedBy = [ "graphical-session.target" ];
    };
  };

  # Desktop launcher so it can also be started manually from a menu.
  xdg.desktopEntries.mouse-wiggle = {
    name = "Mouse Wiggle";
    comment = "Prevent screen lock by wiggling the mouse";
    exec = "${script}/bin/mouse-wiggle";
    icon = "input-mouse";
    terminal = false;
    categories = [ "Utility" ];
  };
}
