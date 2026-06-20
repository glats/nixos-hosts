# mouse-wiggle — on-demand pointer motion helper. Not auto-started.
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

  # Desktop launcher so it can be started manually from a menu.
  xdg.desktopEntries.mouse-wiggle = {
    name = "Mouse Wiggle";
    comment = "Prevent screen lock by wiggling the mouse";
    exec = "${script}/bin/mouse-wiggle";
    icon = "input-mouse";
    terminal = false;
    categories = [ "Utility" ];
  };
}
