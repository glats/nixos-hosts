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

        # Snapshot PIDs before starting DE
        # After logout, any PID not in this file will be killed
        BEFORE_PID_FILE="$HOME/.local/state/xrdp-before-pids"
        mkdir -p "$HOME/.local/state"
        pgrep -u "$USER" > "$BEFORE_PID_FILE"

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
      # Kill any process spawned during the DE session
      echo "===== Cleaning up after $CHOICE session =====" >> "$LOG_FILE"

      # Phase 1: SIGTERM to all PIDs that didn't exist before DE started
      if [ -f "$BEFORE_PID_FILE" ]; then
        for pid in $(pgrep -u "$USER"); do
          if ! grep -qw "$pid" "$BEFORE_PID_FILE"; then
            kill -TERM "$pid" 2>/dev/null || true
          fi
        done
      fi

      # Phase 2: Wait for graceful exit
      sleep 2

      # Phase 3: SIGKILL survivors
      if [ -f "$BEFORE_PID_FILE" ]; then
        for pid in $(pgrep -u "$USER"); do
          if ! grep -qw "$pid" "$BEFORE_PID_FILE"; then
            kill -KILL "$pid" 2>/dev/null || true
          fi
        done
        rm -f "$BEFORE_PID_FILE"
      fi

      # Phase 4: Clear session state files
      rm -rf "$HOME/.local/share/cinnamon/session-state" 2>/dev/null || true
      rm -f "$HOME/.config/mate/session.state" 2>/dev/null || true
      rm -rf "$HOME/.cache/sessions" 2>/dev/null || true

      # Phase 5: Unset DE-specific environment variables
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

  # Disable Cinnamon optional app suite (bulky, warpinator, xviewer, xed, pix, etc.)
  services.cinnamon.apps.enable = false;

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
