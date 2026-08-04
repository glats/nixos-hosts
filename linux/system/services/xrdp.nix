{ config
, lib
, pkgs
, ...
}:

let
  xrdpMateSession =
    pkgs.runCommand "xrdp-mate-session"
      {
        script = pkgs.replaceVars ./xrdp-session.sh {
          inherit (pkgs) dbus systemd xset;
          "mate-session-manager" = pkgs.mate-session-manager;
        };
      }
      ''
        cp "$script" "$out"
        chmod +x "$out"
      '';
in

{
  options.services.xrdp-custom = {
    enable = lib.mkEnableOption "XRDP remote desktop with MATE session" // {
      default = true;
    };
  };

  config = lib.mkIf config.services.xrdp-custom.enable {
    services.xserver = {
      enable = true;
      updateDbusEnvironment = true;
      desktopManager.mate.enable = true;
      displayManager.lightdm.enable = false;
    };

    services.xrdp = {
      enable = true;
      defaultWindowManager = "${xrdpMateSession}";
    };

    environment.systemPackages = with pkgs; [
      mate-polkit
      xset
      zenity
    ];
  };
}
