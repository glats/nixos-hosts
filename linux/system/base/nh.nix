{ config, pkgs, ... }:

{
  programs.nh = {
    enable = true;
    flake = config.users.users.glats.home + "/.nixos";
    clean = {
      enable = true;
      dates = "weekly";
      extraArgs = "--keep-since 4d --keep 3";
    };
  };

  systemd.services.nh-clean.serviceConfig = {
    ExecStartPre = "${pkgs.coreutils}/bin/sleep 600";
    Nice = 19;
    IOSchedulingClass = "idle";
    CPUSchedulingPolicy = "idle";
  };
}
