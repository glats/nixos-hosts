{
  config,
  lib,
  ...
}:

let
  cache = import ../../../shared/nix-cache.nix;

  cacheUrls = [
    "${cache.lanUrl}?priority=30"
    "${cache.remoteUrl}?priority=45"
  ];
in
{
  sops.secrets."nix-cache/netrc" = {
    sopsFile = ../../../secrets/host/${config.networking.hostName}/nix-cache.yaml;
    mode = "0400";
  };

  nix.settings = {
    substituters = lib.mkBefore cacheUrls;

    trusted-public-keys = [
      cache.ncps.publicKey
      cache.harmonia.publicKey
    ];

    trusted-substituters = cacheUrls;

    trusted-users = [ "glats" ];

    netrc-file = config.sops.secrets."nix-cache/netrc".path;
  };
}
