# Optional manual Rust wstunnel launch agent for the managed macm5 client.
#
# No secret is embedded in the plist. relay-client reads the provisioned
# headers file at launch time; credential contents never enter argv or env.
{
  config,
  lib,
  pkgs,
  primaryUser,
  ...
}:

let
  cfg = config.services.ssh-relay;
  defaultCredentialDir = "/Users/${primaryUser}/Library/Application Support/nixos/ssh-relay";
in
{
  options.services.ssh-relay = {
    enable = lib.mkEnableOption "the manual macm5 wstunnel SSH relay client";

    headersFile = lib.mkOption {
      type = lib.types.str;
      default = "${defaultCredentialDir}/headers";
      description = "Runtime-only wstunnel HTTP header file owned by the Mac user.";
    };

    authorizationFile = lib.mkOption {
      type = lib.types.str;
      default = "${defaultCredentialDir}/authorization";
      description = "Regular user-owned relay-token staging path populated after sops materialization.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.headersFile != "";
        message = "services.ssh-relay requires a provisioned headersFile";
      }
      {
        assertion = cfg.headersFile == "${defaultCredentialDir}/headers";
        message = "services.ssh-relay headersFile must use the relayctl-managed path";
      }
      {
        assertion = !lib.hasPrefix builtins.storeDir cfg.headersFile;
        message = "services.ssh-relay headersFile must remain outside the Nix store";
      }
      {
        assertion = cfg.authorizationFile == "${defaultCredentialDir}/authorization";
        message = "services.ssh-relay authorizationFile must use the relayctl-managed path";
      }
      {
        assertion = !lib.hasPrefix builtins.storeDir cfg.authorizationFile;
        message = "services.ssh-relay authorizationFile must remain outside the Nix store";
      }
    ];

    sops.secrets."ssh-relay/authorization" = {
      sopsFile = ../../secrets/shared/ssh-relay.yaml;
      key = "ssh-relay/authorization";
      owner = primaryUser;
      mode = "0600";
    };

    # nix-darwin renders this under the primary user's ~/Library/LaunchAgents,
    # which is the same GUI domain relayctl addresses.
    launchd.user.agents.ssh-relay = {
      serviceConfig = {
        ProgramArguments = [
          "${pkgs.nixos-scripts}/bin/relay-client"
          "${cfg.headersFile}"
          "${pkgs.wstunnel-relay}/bin/wstunnel"
        ];
        KeepAlive = false;
        RunAtLoad = false;
        ProcessType = "Background";
      };
    };
  };
}
