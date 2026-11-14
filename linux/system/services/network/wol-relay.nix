{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.wol-relay;
in
{
  options.services.wol-relay = {
    enable = lib.mkEnableOption "Wake-on-LAN relay that wakes one machine on request";

    port = lib.mkOption {
      type = lib.types.port;
      default = 6667;
      description = "UDP port that receives ARM and STATUS requests.";
    };

    allow = lib.mkOption {
      type = lib.types.str;
      description = "Only requests from this source IP are answered.";
    };

    mac = lib.mkOption {
      type = lib.types.str;
      description = "MAC address that receives the magic packet.";
    };

    broadcast = lib.mkOption {
      type = lib.types.str;
      default = "172.16.0.255:9";
      description = "Broadcast address and port the magic packet is sent to.";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.services.wol-relay = {
      description = "Wake-on-LAN relay for the rog poweroff campaign";
      wantedBy = [ "multi-user.target" ];
      wants = [ "network-online.target" ];
      after = [ "network-online.target" ];
      serviceConfig = {
        ExecStart = ''
          ${pkgs.nixos-scripts}/bin/wol-relay \
            -listen :${toString cfg.port} \
            -allow ${cfg.allow} \
            -mac ${cfg.mac} \
            -broadcast ${cfg.broadcast} \
            -state /var/lib/wol-relay/sent
        '';
        DynamicUser = true;
        StateDirectory = "wol-relay";
        Restart = "always";
        RestartSec = "2s";
        NoNewPrivileges = true;
        ProtectSystem = "strict";
        ProtectHome = true;
      };
    };
  };
}
