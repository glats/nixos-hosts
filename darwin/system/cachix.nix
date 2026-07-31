# Darwin cachix substituters -- fastly mirrors stay here; the shared
# cachix substituters and trusted-public-keys live in shared/cachix.nix.
{ lib, pkgs, ... }:
{
  imports = [
    ../../shared/cachix.nix
  ];

  environment.systemPackages = with pkgs; [ cachix ];

  nix.settings = {
    # Fastly mirrors -- same S3-backed nixos cache, different CDN
    # edges. Mirrors `modules/base/nix.nix` (mkBefore) on linux so
    # mact2 benefits from the same lower-latency fetch path.
    substituters = lib.mkBefore [
      "https://aseipp-nix-cache.freetls.fastly.net"
      "https://aseipp-nix-cache.global.ssl.fastly.net"
    ];
  };
}
