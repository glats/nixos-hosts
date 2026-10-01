{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:

with lib;

let
  # Import centralized provider configuration
  providers = import ./opencode/providers.nix {
    inherit lib;
    activeProviderName = config.home.opencode.activeProviderName;
  };

  # Bare GitHub MCP tool names pruned from both servers (github-personal,
  # github-work): releases, tags, teams, collaborators, labels, repo
  # creation/fork, Copilot assignment, sub-issues, user search. Core
  # workflows (issues, PRs, reviews, branches, commits, content, search)
  # stay enabled. Names follow github/github-mcp-server tool IDs.
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

  v1RuntimeConfig = {
    dir = "opencode";
    label = "default";
    version = "v1";
  };

  v2RuntimeConfig = {
    dir = "opencode-v2";
    label = "v2";
    version = "v2";
  };

  mkRuntimeConfig = import ./opencode/runtime-config.nix;
  v2 = config.home.opencode.v2;
  mkV2Environment = {
    XDG_CONFIG_HOME = "${config.home.homeDirectory}/.config/opencode-v2";
    XDG_DATA_HOME = "${v2.runtimeRoot}/data";
    XDG_CACHE_HOME = "${v2.runtimeRoot}/cache";
    XDG_STATE_HOME = "${v2.runtimeRoot}/state";
    OPENCODE_CONFIG_DIR = "${config.home.homeDirectory}/.config/opencode-v2";
    OPENCODE_DB = "${v2.runtimeRoot}/data/opencode.db";
    TMPDIR = "${v2.runtimeRoot}/tmp";
    OPENCODE_DISABLE_PROJECT_CONFIG = "1";
  };
  mkV2ShellEnvironment = lib.concatStringsSep "\n" (
    (lib.mapAttrsToList (name: value: "export ${name}=${lib.escapeShellArg value}") mkV2Environment)
    ++ [
      ''
        case ":$PATH:" in
          *":${
            lib.makeBinPath [
              pkgs.gentle-ai
              pkgs.git
            ]
          }:"*) ;;
          *) export PATH="${
            lib.makeBinPath [
              pkgs.gentle-ai
              pkgs.git
            ]
          }:$PATH" ;;
        esac
      ''
    ]
  );
  opencodeV2EnvironmentFile = ".local/share/opencode-v2/environment";
  browserMcpServiceCommand = "${v2.browserMcp.bridgePackage}/bin/browsermcp-broker --child ${v2.browserMcp.package}/bin/mcp-server-browsermcp --port ${toString v2.browserMcp.bridgePort}";
  browserMcpLaunchdLabel = "org.nix-community.home.browsermcp";
in
{
  imports = [
    ./opencode/agents.nix
    ./ai-assets.nix
    ./opencode/permissions.nix
    ./opencode/plugins.nix
  ];

  options.home.opencode = {
    enable = mkEnableOption "OpenCode configuration with declarative JSON generation";

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

    compaction = mkOption {
      type = types.submodule {
        options = {
          auto = mkOption {
            type = types.bool;
            default = true;
            description = "Automatically compact the session when context is full.";
          };
          prune = mkOption {
            type = types.bool;
            default = true;
            description = "Remove old tool outputs to save tokens (upstream default: false).";
          };
          reserved = mkOption {
            type = types.int;
            default = 10000;
            description = "Token buffer kept free so compaction never overflows the window.";
          };
        };
      };
      description = ''
        Session compaction settings, serialized as the top-level
        `compaction` key. Key set verified against the pinned OpenCode
        1.18.18: `keep.tokens`/`buffer` are unshipped v2 draft keys and
        must NOT be emitted.
      '';
    };

    v2 = {
      enable = mkEnableOption "isolated OpenCode V2 runtime" // {
        default = true;
      };

      runtimeRoot = mkOption {
        type = types.str;
        default = "${config.home.homeDirectory}/.local/opencode-v2";
        description = "Version-scoped data, cache, state, database, and temporary root for OpenCode V2.";
      };

      projectConfigCommand = mkOption {
        type = types.str;
        default = "opencode2-project";
        description = "Explicit command that permits V2-compatible project configuration.";
      };

      browserMcp = {
        enable = mkOption {
          type = types.bool;
          default = true;
          description = "Enable the pinned BrowserMCP singleton in the global V2 configuration.";
        };

        package = mkOption {
          type = types.package;
          default = pkgs.browsermcp-v2;
          description = "Pinned BrowserMCP package used by the V2 global MCP server.";
        };

        bridgePackage = mkOption {
          type = types.package;
          default = pkgs.nixos-scripts;
          description = "Package providing the loopback BrowserMCP broker.";
        };

        bridgePort = mkOption {
          type = types.port;
          default = 9010;
          description = "Loopback-only port served by the BrowserMCP broker; collisions exit without restarting or replacing their owner.";
        };

        location = mkOption {
          type = types.enum [ "global" ];
          default = "global";
          readOnly = true;
          description = "BrowserMCP is emitted only in the global V2 configuration to preserve its singleton listener.";
        };
      };

    };
  };

  config = mkMerge [
    # Main configuration
    (mkIf config.home.opencode.enable {
      home.packages = with pkgs; [
        gentle-ai
        engram
        rtk
        poppler-utils # PDF page rendering: needed by OpenCode read tool and Claude Code for PDF support
      ];

      home.sessionVariables = {
        RTK_TELEMETRY_DISABLED = "1";
      };

      home.file = mkIf config.home.opencode.plugins.warden.enable {
        ".config/opencode/opencode-warden.json".text = builtins.toJSON {
          audit.filePath = "${config.home.homeDirectory}/.local/state/opencode/warden/audit.log";
        };
      };

      # Export API keys from sops secrets at shell startup
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

    # Single runtime configuration
    (mkIf config.home.opencode.enable (mkRuntimeConfig {
      inherit
        config
        lib
        pkgs
        providers
        ;
      cfg = config.home.opencode;
      runtimeConfig = v1RuntimeConfig;
    }))

    (mkIf config.home.opencode.v2.enable (mkRuntimeConfig {
      inherit
        config
        lib
        pkgs
        providers
        ;
      cfg = config.home.opencode;
      runtimeConfig = v2RuntimeConfig;
    }))

    (mkIf config.home.opencode.v2.enable {
      home.file.${opencodeV2EnvironmentFile}.text = mkV2ShellEnvironment;

      assertions =
        lib.optional (pkgs.stdenv.isLinux && v2.browserMcp.enable) {
          assertion =
            lib.elem browserMcpServiceCommand config.systemd.user.services.browsermcp.Service.ExecStart
            && config.systemd.user.services.browsermcp.Service.Restart == "on-failure";
          message = "BrowserMCP must use the loopback broker under a restarting systemd user service.";
        }
        ++ lib.optional (pkgs.stdenv.isDarwin && v2.browserMcp.enable) {
          assertion =
            config.launchd.agents.browsermcp.config.ProgramArguments == [
              "${v2.browserMcp.bridgePackage}/bin/browsermcp-broker"
              "--child"
              "${v2.browserMcp.package}/bin/mcp-server-browsermcp"
              "--port"
              (toString v2.browserMcp.bridgePort)
            ]
            && config.launchd.agents.browsermcp.config.KeepAlive.Crashed;
          message = "BrowserMCP must use the loopback broker under a restarting launchd agent.";
        }
        ++ [
          {
            assertion =
              config.home.file.${opencodeV2EnvironmentFile}.text == mkV2ShellEnvironment
              && lib.hasInfix "managed-runtime.activation" config.home.activation.restartOpencodeV2.data
              && lib.hasInfix "opencode2 service restart" config.home.activation.restartOpencodeV2.data
              && lib.hasInfix "/bin/cp --remove-destination" config.home.activation.restartOpencodeV2.data
              && !(lib.hasInfix "opencode2 reload" config.home.activation.restartOpencodeV2.data);
            message = "OpenCode V2 activation must restart after managed runtime changes and replace its read-only stamp.";
          }
        ];

      systemd.user.services.browsermcp = lib.mkIf (pkgs.stdenv.isLinux && v2.browserMcp.enable) {
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

      launchd.agents.browsermcp = lib.mkIf (pkgs.stdenv.isDarwin && v2.browserMcp.enable) {
        enable = true;
        config = {
          ProgramArguments = [
            "${v2.browserMcp.bridgePackage}/bin/browsermcp-broker"
            "--child"
            "${v2.browserMcp.package}/bin/mcp-server-browsermcp"
            "--port"
            (toString v2.browserMcp.bridgePort)
          ];
          KeepAlive = {
            Crashed = true;
            SuccessfulExit = false;
          };
          ProcessType = "Background";
          RunAtLoad = true;
        };
      };

      home.activation.restartOpencodeV2 = config.lib.dag.entryAfter [ "setupOpencodePluginRuntime-v2" ] ''
        runtime_root=${lib.escapeShellArg v2.runtimeRoot}
        stamp="$runtime_root/managed-runtime.activation"
        fingerprint=${
          pkgs.writeText "opencode-v2-managed-runtime-fingerprint" (
            builtins.hashString "sha256" (
              lib.concatStringsSep "\n" [
                config.home.activation."setupOpencodePluginRuntime-v2".data
                (toString config.home.file.".config/opencode-v2/opencode.json".source)
                config.home.file.${opencodeV2EnvironmentFile}.text
                (toString pkgs.opencode-v2)
              ]
            )
          )
        }

        mkdir -p "$runtime_root"
        if [ ! -f "$stamp" ] || ! ${pkgs.diffutils}/bin/cmp -s "$fingerprint" "$stamp"; then
          source "${config.home.homeDirectory}/.local/share/opencode-v2/environment"
          if ! ${pkgs.opencode-v2}/bin/opencode2 service restart; then
            echo "restartOpencodeV2: native service restart failed" >&2
            exit 1
          fi
          if ! ${pkgs.coreutils}/bin/cp --remove-destination "$fingerprint" "$stamp"; then
            echo "restartOpencodeV2: failed to record the active configuration" >&2
            exit 1
          fi
        fi
      '';

    })
  ];
}
