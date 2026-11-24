{ pkgs, ... }:
{
  users.groups.lolla-watch = { };
  users.users.lolla-watch = {
    isSystemUser = true;
    group = "lolla-watch";
  };

  systemd.services.lolla-watch = {
    description = "Check Lollapalooza Chile for the 2027 schedule";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    serviceConfig = {
      Type = "oneshot";
      User = "lolla-watch";
      StateDirectory = "lolla-watch";
      StateDirectoryMode = "0755";
      ProtectSystem = "strict";
      ProtectHome = true;
      NoNewPrivileges = true;
      PrivateTmp = true;
      ExecStart = "${pkgs.nixos-scripts}/bin/lolla-watch";
    };
  };

  systemd.timers.lolla-watch = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "5min";
      OnUnitActiveSec = "1h";
    };
  };
}
