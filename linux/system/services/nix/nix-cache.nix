{
  config,
  pkgs,
  lib,
  ...
}:

let
  cacheCfg = import ../../../../shared/nix-cache.nix;
  prewarmFlake = "git+https://github.com/glats/nixos-hosts?ref=master";
in

{
  sops.secrets."nix-cache/harmonia_signing_key" = {
    sopsFile = ../../../../secrets/host/thinkcentre/nix-cache.yaml;
    mode = "0400";
  };

  sops.secrets."nix-cache/ncps_signing_key" = {
    sopsFile = ../../../../secrets/host/thinkcentre/nix-cache.yaml;
    mode = "0400";
  };

  services.harmonia.cache = {
    enable = true;
    signKeyPaths = [
      config.sops.secrets."nix-cache/harmonia_signing_key".path
    ];
  };

  services.ncps = {
    enable = true;
    cache.hostName = "thinkcentre";
    cache.secretKeyPath = config.sops.secrets."nix-cache/ncps_signing_key".path;
    cache.maxSize = "100G";
    cache.lru.schedule = "17 3 * * *";
    cache.upstream.urls = [
      "http://127.0.0.1:${toString cacheCfg.harmonia.port}"
    ]
    ++ config.nix.settings.substituters
    ++ (config.nix.settings.extra-substituters or [ ]);
    cache.upstream.publicKeys = [
      cacheCfg.harmonia.publicKey
    ]
    ++ config.nix.settings.trusted-public-keys
    ++ config.nix.settings.extra-trusted-public-keys;
  };

  nix.daemonCPUSchedPolicy = "idle";
  nix.daemonIOSchedClass = "idle";

  nix.settings.trusted-users = [ "glats" ];

  systemd.services.nix-cache-prewarm = {
    description = "Prewarm the thinkcentre Nix binary cache with all host closures";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    path = [
      pkgs.nix
      pkgs.git
    ];
    serviceConfig = {
      Type = "oneshot";
      StateDirectory = "nix-cache-prewarm";
      Nice = 19;
      IOSchedulingClass = "idle";
      ExecStart = "${pkgs.nixos-scripts}/bin/nix-cache prewarm --flake ${lib.escapeShellArg prewarmFlake} --state-dir /var/lib/nix-cache-prewarm --max-load 2.0";
    };
  };

  systemd.timers.nix-cache-prewarm = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "15m";
      OnUnitActiveSec = "6h";
      RandomizedDelaySec = "15m";
      Persistent = true;
    };
  };
}
