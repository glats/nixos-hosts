{ config, lib, pkgs, ... }:

let
  # Interface mapping by hostname
  wolInterface =
    if config.networking.hostName == "rog" then "enp3s0"
    else if config.networking.hostName == "thinkcentre" then "enp0s31f6"
    else null;
in
{
  systemd.services.wol-enable = lib.mkIf (wolInterface != null) {
    description = "Enable Wake-on-LAN";
    after = [ "NetworkManager.service" ];
    wants = [ "NetworkManager.service" ];
    wantedBy = [ "multi-user.target" "sleep.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.ethtool}/bin/ethtool -s ${wolInterface} wol g";
      RemainAfterExit = true;
    };
  };
}
