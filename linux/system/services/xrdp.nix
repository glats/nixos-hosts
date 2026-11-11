{
  config,
  lib,
  pkgs,
  ...
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
      extraConfDirCommands = ''
        substituteInPlace "$out/xrdp.ini" \
          --replace-fail EnableSyslog=false EnableSyslog=true
        sed -i \
          -e '/^\[Logging\]/,/^\[/{s/^LogLevel=.*/LogLevel=DEBUG/;s/^#EnableConsole=.*/EnableConsole=true/;s/^#ConsoleLevel=.*/ConsoleLevel=DEBUG/}' \
          $out/xrdp.ini $out/sesman.ini
        substituteInPlace $out/xrdp.ini \
          --replace-fail "security_layer=negotiate" "security_layer=tls" \
          --replace-fail "crypt_level=high" "crypt_level=medium"
        sed -i \
          -e '/^\[ChansrvLogging\]/,/^\[/s/^LogLevel=.*/LogLevel=DEBUG/' \
          $out/sesman.ini
      '';
    };

    environment.systemPackages = with pkgs; [
      mate-polkit
      xset
      zenity
    ];

    # xrdp-sesman reads sesman.ini once at startup and keeps the session X
    # server module path from it, so a sesman that survives a switch keeps
    # using the previous xorgxrdp. services.xrdp sets restartIfChanged = false
    # so that ordinary switches never kill running RDP sessions, which leaves
    # the sesman stale whenever the xrdp package itself changes. Restart it
    # exactly in that case: the xrdp daemon restarts anyway when the package
    # changes, so the transport is dropped either way.
    systemd.services.xrdp-sesman.restartTriggers = [ pkgs.xrdp ];
  };
}
