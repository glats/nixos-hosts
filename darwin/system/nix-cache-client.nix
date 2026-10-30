{
  config,
  lib,
  primaryUser,
  ...
}:

let
  cache = import ../../shared/nix-cache.nix;

  cacheUrls = [
    "${cache.lanUrl}?priority=30"
    "${cache.remoteUrl}?priority=45"
  ];
in
{
  sops.secrets."nix-cache/netrc" = {
    sopsFile = ../../secrets/host/macm5/nix-cache.yaml;
    mode = "0400";
  };

  determinateNix.customSettings = {
    substituters = lib.mkBefore cacheUrls;

    trusted-public-keys = [
      cache.ncps.publicKey
      cache.harmonia.publicKey
    ];

    trusted-users = [
      "root"
      primaryUser
    ];
  };

  determinateNix.determinateNixd.authentication.additionalNetrcSources = [
    config.sops.secrets."nix-cache/netrc".path
  ];
}
