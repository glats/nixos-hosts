{ config, lib, pkgs, ... }:

let
  # Interface mapping by hostname
  wolInterface =
    if config.networking.hostName == "rog" then "enp3s0"
    else if config.networking.hostName == "thinkcentre" then "enp0s31f6"
    else null;
in
{
  networking.interfaces.${wolInterface}.wakeOnLan.enable = lib.mkIf (wolInterface != null) true;

  systemd.services.wol-enable = lib.mkIf (wolInterface != null) {
    description = "Enable Wake-on-LAN";
    after = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.ethtool}/bin/ethtool -s ${wolInterface} wol g";
      RemainAfterExit = true;
    };
  };
}
