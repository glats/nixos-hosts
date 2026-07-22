# nh - yet another NixOS/nix helper
# Provides `nh os switch` with nix-output-monitor integration
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
}
