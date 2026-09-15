# Darwin Cachix settings. Determinate owns the daemon, so these values must
# be emitted through determinateNix.customSettings rather than nix.settings.
{ lib, pkgs, ... }:
{
  environment.systemPackages = with pkgs; [ cachix ];

  determinateNix.customSettings = lib.mkMerge [
    {
      # Fastly mirrors are tried before the shared caches.
      substituters = lib.mkBefore [
        "https://aseipp-nix-cache.freetls.fastly.net"
        "https://aseipp-nix-cache.global.ssl.fastly.net"
      ];
    }
    (import ../../shared/cachix-settings.nix)
  ];
}
