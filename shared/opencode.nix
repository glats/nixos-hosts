{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:

with lib;

let
  providers = import ./opencode/providers.nix {
    inherit lib;
    activeProviderName = config.home.opencode.activeProviderName;
  };

  githubRareTools = [
    "assign_copilot_to_issue"
    "create_repository"
    "fork_repository"
    "get_label"
    "get_latest_release"
    "get_release_by_tag"
    "get_tag"
    "get_team_members"
    "get_teams"
    "list_issue_types"
    "list_releases"
    "list_repository_collaborators"
    "list_tags"
    "request_copilot_review"
    "search_users"
    "sub_issue_write"
  ];

  mkRuntimeConfig = import ./opencode/runtime-config.nix;
  cfg = config.home.opencode;
  openfangEnabled = config.home ? openfang && config.home.openfang.enable;
  nativeDiscovery = pkgs.runCommand "gentle-ai-native-discovery" { } ''
    mkdir -p "$out/bin"
    ln -s ${pkgs.opencode}/bin/opencode "$out/bin/opencode"
  '';
  gentleManaged =
    pkgs.runCommand "gentle-ai-managed"
      {
        nativeBuildInputs = [ pkgs.makeBinaryWrapper ];
      }
      ''
        mkdir -p "$out/bin"
        makeBinaryWrapper ${pkgs.gentle-ai}/bin/gentle-ai "$out/bin/gentle-ai" \
          --set GENTLE_AI_OPENCODE_RELAY_CONTRACT gentle-ai.opencode-relay/v2-staged \
          --prefix PATH : ${
            lib.makeBinPath [
              nativeDiscovery
              pkgs.git
            ]
          }
      '';
  opencodePackage =
    pkgs.runCommand "opencode-managed"
      {
        nativeBuildInputs = [ pkgs.makeBinaryWrapper ];
      }
      ''
        mkdir -p "$out/bin"
        makeBinaryWrapper ${pkgs.opencode}/bin/opencode "$out/bin/opencode" \
          --set-default OPENCODE_DISABLE_PROJECT_CONFIG 1 \
          --prefix PATH : ${
            lib.makeBinPath [
              gentleManaged
              pkgs.git
            ]
          }
      '';
  browserMcpServiceCommand = "${cfg.browserMcp.bridgePackage}/bin/browsermcp-broker --child ${cfg.browserMcp.package}/bin/mcp-server-browsermcp --port ${toString cfg.browserMcp.bridgePort}";
  browserMcpLaunchdLabel = "org.nix-community.home.browsermcp";
in
{
  imports = [
    ./opencode/agents.nix
    ./ai-assets.nix
    ./opencode/permissions.nix
  ];

  options.home.opencode = {
    enable = mkEnableOption "OpenCode configuration with declarative JSON generation";
    browserMcp = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Enable the pinned BrowserMCP singleton.";
      };
      package = mkOption {
        type = types.package;
        default = pkgs.browsermcp-v2;
        description = "Pinned BrowserMCP package.";
      };
      bridgePackage = mkOption {
        type = types.package;
        default = pkgs.nixos-scripts;
        description = "Package providing the loopback BrowserMCP broker.";
      };
      bridgePort = mkOption {
        type = types.port;
        default = 9010;
        description = "Loopback-only broker port.";
      };
      location = mkOption {
        type = types.enum [ "global" ];
        default = "global";
        readOnly = true;
        description = "BrowserMCP is emitted globally.";
      };
    };

    extraInitContent = mkOption {
      type = types.lines;
      default = "";
      description = "Extra zsh initContent appended after API key exports. Use for platform-specific shell setup.";
    };

    activeProviderName = mkOption {
      type = types.str;
      default = lib.mkDefault "opencode-go-full";
      description = ''
        Name of the active OpenCode provider tier (e.g. "opencode-go-full",
        "github-copilot"). Per-host plain assignments override this default
        without needing `mkForce`.
      '';
    };

    disabledTools = mkOption {
      type = types.listOf types.str;
      default = concatMap (server: map (tool: "${server}_${tool}") githubRareTools) [
        "github-personal"
        "github-work"
      ];
      description = ''
        Fully-qualified tool names disabled globally (serialized as
        tools."name" = false). OpenCode removes disabled tools from the
        provider request entirely, so their schemas stop costing tokens
        on every turn. Default prunes rarely-used GitHub tool families
        (releases, tags, teams, collaborators, repo creation/fork,
        Copilot, sub-issues) from both GitHub MCP servers.
      '';
    };

  };

  config = mkMerge [
    (mkIf config.home.opencode.enable {
      home.activation.migrateOpencodeLayout = config.lib.dag.entryBefore [ "checkLinkTargets" ] ''
        ${pkgs.nixos-scripts}/bin/opencode-layout-migrate ${
          lib.optionalString (!openfangEnabled) "--retire-openfang-skills"
        }
      '';

      home.packages = with pkgs; [
        gentleManaged
        opencodePackage
        engram
        rtk
        poppler-utils
      ];

      home.sessionVariables = {
        RTK_TELEMETRY_DISABLED = "1";
      };

      programs.zsh.initContent = lib.mkAfter ''
              if [ -f "${config.sops.secrets."opencode/nvidia_api_key".path}" ]; then
                export NVIDIA_API_KEY="$(cat ${config.sops.secrets."opencode/nvidia_api_key".path})"
              fi
          if [ -f "${config.sops.secrets."opencode/opencode_go_api_key".path}" ]; then
            export OPENCODE_API_KEY="$(cat ${config.sops.secrets."opencode/opencode_go_api_key".path})"
          fi
        ${config.home.opencode.extraInitContent}
      '';
    })

    (mkIf config.home.opencode.enable (mkRuntimeConfig {
      inherit
        config
        lib
        pkgs
        providers
        gentleManaged
        openfangEnabled
        ;
      cfg = config.home.opencode;
    }))

    (mkIf config.home.opencode.enable {
      assertions =
        lib.optional (pkgs.stdenv.isLinux && cfg.browserMcp.enable) {
          assertion =
            lib.elem browserMcpServiceCommand config.systemd.user.services.browsermcp.Service.ExecStart
            && config.systemd.user.services.browsermcp.Service.Restart == "on-failure";
          message = "BrowserMCP must use the loopback broker under a restarting systemd user service.";
        }
        ++ lib.optional (pkgs.stdenv.isDarwin && cfg.browserMcp.enable) {
          assertion =
            config.launchd.agents.browsermcp.config.ProgramArguments == [
              "${cfg.browserMcp.bridgePackage}/bin/browsermcp-broker"
              "--child"
              "${cfg.browserMcp.package}/bin/mcp-server-browsermcp"
              "--port"
              (toString cfg.browserMcp.bridgePort)
            ]
            && config.launchd.agents.browsermcp.config.KeepAlive.Crashed;
          message = "BrowserMCP must use the loopback broker under a restarting launchd agent.";
        };

      systemd.user.services.browsermcp = lib.mkIf (pkgs.stdenv.isLinux && cfg.browserMcp.enable) {
        Unit = {
          Description = "BrowserMCP singleton broker";
          After = [ "default.target" ];
        };
        Service = {
          Type = "simple";
          ExecStart = browserMcpServiceCommand;
          Restart = "on-failure";
          RestartSec = "5s";
          RestartPreventExitStatus = "78";
        };
        Install.WantedBy = [ "default.target" ];
      };

      launchd.agents.browsermcp = lib.mkIf (pkgs.stdenv.isDarwin && cfg.browserMcp.enable) {
        enable = true;
        config = {
          ProgramArguments = [
            "${cfg.browserMcp.bridgePackage}/bin/browsermcp-broker"
            "--child"
            "${cfg.browserMcp.package}/bin/mcp-server-browsermcp"
            "--port"
            (toString cfg.browserMcp.bridgePort)
          ];
          KeepAlive = {
            Crashed = true;
            SuccessfulExit = false;
          };
          ProcessType = "Background";
          RunAtLoad = true;
        };
      };

    })
  ];
}
