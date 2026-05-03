{ config, lib, pkgs, ... }:

let
  # Common XRDP session preamble: dbus setup + disable screen blanking
  # DPMS/screen blanking causes disconnects in virtual sessions
  xrdpPreamble = ''
    ${pkgs.dbus}/bin/dbus-update-activation-environment --systemd --all
    ${pkgs.xset}/bin/xset s off 2>/dev/null || true
    ${pkgs.xset}/bin/xset -dpms 2>/dev/null || true
    ${pkgs.xset}/bin/xset s noblank 2>/dev/null || true
  '';

  # Rofi session picker — shown on xrdp login before launching a DE.
  # Uses icon specs so rofi shows the DE logo next to each choice.
  # Papirus has: mate-desktop, start-here-xfce
  # Cinnamon icon comes from the cinnamon package itself.
  # Per-user override: create ~/startwm.sh to bypass the picker entirely.
  #
  # Loop-based: after DE logout, return to picker instead of dropping connection.
  sessionPicker = pkgs.writeShellScript "xrdp-session-picker" ''
    ${xrdpPreamble}

    mkdir -p "$HOME/.local/state"

    while true; do
      CHOICE=$(printf 'MATE\0icon\x1fmate-desktop\nXFCE\0icon\x1fstart-here-xfce\nCinnamon\0icon\x1f${pkgs.cinnamon}/share/icons/hicolor/scalable/apps/cinnamon.svg' | \
        ${pkgs.rofi}/bin/rofi \
        -dmenu \
        -i \
        -p "Desktop" \
        -font "Sans 14" \
        -show-icons \
        -icon-theme "Papirus-Dark" \
        -width 25 \
        -lines 3)

      # User cancelled (Escape or closed rofi) — exit loop and disconnect
      if [ -z "$CHOICE" ]; then
        break
      fi

      case "$CHOICE" in
        MATE)
          LOG_FILE="$HOME/.local/state/xrdp-mate.log"
          ;;
        XFCE)
          LOG_FILE="$HOME/.local/state/xrdp-xfce.log"
          ;;
        Cinnamon)
          LOG_FILE="$HOME/.local/state/xrdp-cinnamon.log"
          ;;
        *)
          CHOICE="MATE"
          LOG_FILE="$HOME/.local/state/xrdp-mate.log"
          ;;
      esac

      {
        echo
        echo "===== $(date) ====="
        echo "choice=$CHOICE"
        echo "user=$USER"
        echo "display=$DISPLAY"
      } >> "$LOG_FILE"

      (
        exec >> "$LOG_FILE" 2>&1
        set -x

        # Export DE-specific env vars so the session and child processes know context
        export XRDP_SESSION=1

        case "$CHOICE" in
          MATE)
            export DESKTOP_SESSION=mate
            export XDG_CURRENT_DESKTOP=MATE
            ${pkgs.mate-session-manager}/bin/mate-session
            ;;
          XFCE)
            export DESKTOP_SESSION=xfce
            export XDG_CURRENT_DESKTOP=XFCE
            ${pkgs.xfce4-session}/bin/xfce4-session
            ;;
          Cinnamon)
            export DESKTOP_SESSION=cinnamon
            export XDG_CURRENT_DESKTOP=X-Cinnamon
            ${pkgs.cinnamon-session}/bin/cinnamon-session
            ;;
        esac
      )

      # ── SESSION CLEANUP ──
      # After a DE exits, kill lingering processes and clear state
      # to prevent conflicts when switching to a different DE.

      echo "===== Cleaning up after $CHOICE session =====" >> "$LOG_FILE"

      # Phase 1: Send SIGTERM to known DE processes
      for proc in cinnamon cinnamon-session cinnamon-launcher cinnamon-settings-daemon mate-panel mate-settings-daemon marco xfce4-panel xfce4-session xfwm4 muffin gnome-shell gnome-panel; do
        pkill -x "$proc" 2>/dev/null || true
      done

      # Phase 2: Wait for graceful exit
      sleep 2

      # Phase 3: Send SIGKILL to stubborn processes
      for proc in cinnamon cinnamon-session cinnamon-launcher cinnamon-settings-daemon mate-panel mate-settings-daemon marco xfce4-panel xfce4-session xfwm4 muffin gnome-shell gnome-panel; do
        pkill -9 -x "$proc" 2>/dev/null || true
      done

      # Phase 4: Verify cleanup
      sleep 1
      remaining=$(pgrep -x "cinnamon\|cinnamon-session\|mate-panel\|xfce4-panel\|muffin\|marco\|xfwm4" 2>/dev/null | wc -l)
      if [ "$remaining" -gt 0 ]; then
        echo "WARNING: $remaining DE processes still running after cleanup" >> "$LOG_FILE"
        sleep 2
      fi

      # Phase 5: Clear session state files that could trigger auto-restore
      rm -rf "$HOME/.local/share/cinnamon/session-state" 2>/dev/null || true
      rm -f "$HOME/.config/mate/session.state" 2>/dev/null || true
      rm -rf "$HOME/.cache/sessions" 2>/dev/null || true

      # Phase 6: Unset DE-specific environment variables
      unset DESKTOP_SESSION XDG_CURRENT_DESKTOP XDG_SESSION_DESKTOP XDG_SESSION_TYPE XDG_SEAT
    done
  '';
in

{
  services.xserver = {
    enable = true;
    updateDbusEnvironment = true;
    desktopManager.mate.enable = true;
    desktopManager.xfce.enable = true;
    desktopManager.cinnamon.enable = true;
    displayManager.lightdm.enable = false;
  };

  services.xrdp = {
    enable = true;
    defaultWindowManager = "${sessionPicker}";
  };

  environment.systemPackages = with pkgs; [
    mate-polkit
    xset
    zenity
  ];
}
