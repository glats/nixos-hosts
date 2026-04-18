{ config, pkgs, lib, ... }:

{
  systemd.services.asus-fan-control = {
    description = "Fan control for ASUS devices running Linux";
    after = [ "multi-user.target" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.asus-fan-control}/bin/asus-fan-control";
      RemainAfterExit = true;
    };
  };
}
