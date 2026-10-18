{ lib, pkgs, ... }:

let
  script = pkgs.writeScriptBin "mouse-wiggle" ''
    #!/usr/bin/env bash
    # Move mouse by 1 pixel every 50 seconds to inhibit idle lock.
    # Stop automatically when any fullscreen window is detected.

    set -euo pipefail

    # graphical-session.target starts before uwsm exports the Hyprland
    # environment into the systemd user manager; wait bounded for it or exit
    # cleanly so Restart=on-failure never exhausts the start limit.
    if [ -z "''${HYPRLAND_INSTANCE_SIGNATURE-}" ]; then
      waited=0
      while [ "$waited" -lt 60 ]; do
        sig="$(systemctl --user show-environment 2>/dev/null | sed -n 's/^HYPRLAND_INSTANCE_SIGNATURE=//p' || true)"
        if [ -n "$sig" ]; then
          break
        fi
        sleep 1
        waited=$((waited + 1))
      done
      if [ -z "$sig" ]; then
        exit 0
      fi
      export HYPRLAND_INSTANCE_SIGNATURE="$sig"
    fi

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
          # Move cursor by 1px relative to current position.
          # hyprctl dispatch movecursor is ABSOLUTE, so we must read
          # current position first, then add 1 to each axis.
          CURSOR_POS=$(hyprctl cursorpos 2>/dev/null || echo "0,0")
          X=$(echo "$CURSOR_POS" | cut -d',' -f1)
          Y=$(echo "$CURSOR_POS" | cut -d',' -f2)
          hyprctl dispatch movecursor "$((X + 1))" "$((Y + 1))" 2>/dev/null || true
        fi
        sleep 50
      done
    }

    main
  '';
in
{
  home.packages = [ script ];

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

  xdg.desktopEntries.mouse-wiggle = {
    name = "Mouse Wiggle";
    comment = "Prevent screen lock by wiggling the mouse";
    exec = "${script}/bin/mouse-wiggle";
    icon = "input-mouse";
    terminal = false;
    categories = [ "Utility" ];
  };
}
