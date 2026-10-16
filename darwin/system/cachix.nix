{ lib, pkgs, ... }:
{
  environment.systemPackages = with pkgs; [ cachix ];

  determinateNix.customSettings = lib.mkMerge [
    {
      substituters = lib.mkBefore [
        "https://aseipp-nix-cache.freetls.fastly.net"
        "https://aseipp-nix-cache.global.ssl.fastly.net"
      ];
    }
    (import ../../shared/cachix-settings.nix)
  ];
}
