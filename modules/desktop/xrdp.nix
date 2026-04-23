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
  # Uses the user's rofi theme from home-manager if available,
  # otherwise falls back to rofi's built-in default theme.
  # Per-user override: create ~/startwm.sh to bypass the picker entirely.
  sessionPicker = pkgs.writeShellScript "xrdp-session-picker" ''
    ${xrdpPreamble}

    CHOICE=$(printf '%s\n' MATE XFCE Cinnamon | ${pkgs.rofi}/bin/rofi \
      -dmenu \
      -i \
      -p "Desktop" \
      -font "Sans 14" \
      -show-icons \
      -width 25 \
      -lines 3)

    mkdir -p "$HOME/.local/state"

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

    exec >> "$LOG_FILE" 2>&1
    set -x

    case "$CHOICE" in
      MATE)      exec ${pkgs.mate-session-manager}/bin/mate-session ;;
      XFCE)      exec ${pkgs.xfce4-session}/bin/xfce4-session ;;
      Cinnamon)  exec ${pkgs.cinnamon-session}/bin/cinnamon-session ;;
    esac
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
  ];
}
