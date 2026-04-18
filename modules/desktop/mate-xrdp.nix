{ config, lib, pkgs, ... }:

let
  mateXrdpSession = pkgs.writeShellScript "mate-xrdp-session" ''
    ${pkgs.dbus}/bin/dbus-update-activation-environment --systemd --all

    # Disable screen blanking for xrdp sessions (DPMS causes issues in virtual sessions)
    ${pkgs.xset}/bin/xset s off 2>/dev/null || true
    ${pkgs.xset}/bin/xset -dpms 2>/dev/null || true
    ${pkgs.xset}/bin/xset s noblank 2>/dev/null || true

    exec ${pkgs.mate-session-manager}/bin/mate-session
  '';
in

{
  services.xserver = {
    enable = true;
    updateDbusEnvironment = true;
    desktopManager.mate.enable = true;
    displayManager.lightdm.enable = false;
  };

  services.xrdp = {
    enable = true;
    defaultWindowManager = "${mateXrdpSession}";
  };

  environment.systemPackages = with pkgs; [
    mate-polkit
    xset
  ];
}
