{ pkgs, ... }:

{
  networking.interfaces.enp3s0.wakeOnLan.enable = true;

  systemd.services.wol-enable = {
    description = "Enable Wake-on-LAN";
    after = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.ethtool}/bin/ethtool -s enp3s0 wol g";
      RemainAfterExit = true;
    };
  };
}
