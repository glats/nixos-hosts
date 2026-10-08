# Optional Rust wstunnel reverse relay server for macm5 -> rog SSH.
#
# The module is intentionally disabled until the runtime restriction file
# has been provisioned. Importing it alone cannot start a
# listener or create a secret dependency.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.ssh-relay;
in
{
  options.services.ssh-relay = {
    enable = lib.mkEnableOption "the loopback-only wstunnel SSH relay";

    restrictionsFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = "Runtime-only wstunnel restriction file owned by the relay user.";
    };

    listenPort = lib.mkOption {
      type = lib.types.port;
      default = 4012;
      description = "Loopback HTTP port nginx uses for the relay WebSocket.";
    };

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.wstunnel-relay;
      description = "Pinned Rust wstunnel package used by the relay server.";
    };
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.enable {
      assertions = [
        {
          assertion = cfg.restrictionsFile != null;
          message = "services.ssh-relay.restrictionsFile must be provisioned before enabling the relay";
        }
        {
          assertion =
            cfg.restrictionsFile == null || (!lib.hasPrefix builtins.storeDir (toString cfg.restrictionsFile));
          message = "services.ssh-relay restrictions must remain outside the Nix store";
        }
      ];
    })

    (lib.mkIf (cfg.enable && cfg.restrictionsFile != null) {

      users.groups.ssh-relay = { };
      users.users.ssh-relay = {
        isSystemUser = true;
        group = "ssh-relay";
      };

      # Root controls replacement; the service reads only its own 0600 file.
      # Unlike /run, this policy survives nightly server shutdowns.
      systemd.tmpfiles.rules = [ "d /var/lib/ssh-relay 0755 root root -" ];

      systemd.services.ssh-relay = {
        description = "Loopback-only wstunnel SSH relay";
        wantedBy = [ "multi-user.target" ];
        after = [ "network-online.target" ];
        wants = [ "network-online.target" ];
        unitConfig.ConditionPathExists = "!/var/lib/ssh-relay/promotion-pending";
        serviceConfig = {
          User = "ssh-relay";
          Group = "ssh-relay";
          ExecStart = "${cfg.package}/bin/wstunnel server --log-lvl off --restrict-config ${cfg.restrictionsFile} ws://127.0.0.1:${toString cfg.listenPort}";
          ExecStartPre = [
            "${pkgs.coreutils}/bin/test ! -L ${cfg.restrictionsFile}"
            "${pkgs.coreutils}/bin/test -O ${cfg.restrictionsFile}"
            # systemd expands specifiers before Bash: %% preserves stat's formats.
            "${pkgs.bash}/bin/bash -eu -c 'test \"$(stat -c %%a \"$1\")\" = 600' -- ${cfg.restrictionsFile}"
            "${pkgs.bash}/bin/bash -eu -c 'resolved=$(readlink -f -- \"$1\"); case \"$resolved\" in /nix/store|/nix/store/*) exit 1;; esac; parent=$(dirname \"$resolved\"); mode=$(stat -c %%a \"$parent\"); test \"$((8#$mode & 0022))\" = 0; owner=$(stat -c %%u \"$parent\"); test \"$owner\" = 0 -o \"$owner\" = \"$(id -u)\"' -- ${cfg.restrictionsFile}"
          ];
          Restart = "on-failure";
          RestartSec = 5;
          KillMode = "control-group";
          TimeoutStopSec = "5s";
          NoNewPrivileges = true;
          PrivateTmp = true;
          ProtectHome = true;
          ProtectSystem = "strict";
          RestrictAddressFamilies = [
            "AF_INET"
            "AF_INET6"
          ];
        };
      };
    })
  ];
}
