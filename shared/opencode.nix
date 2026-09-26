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
    lib.mapAttrsToList (name: value: "export ${name}=${lib.escapeShellArg value}") mkV2Environment
  );
  mkV2SystemdEnvironment = lib.mapAttrsToList (name: value: "${name}=${value}") mkV2Environment;
  opencodeV2EnvironmentFile = ".local/share/opencode-v2/environment";
  opencodeV2ServiceCommand = "${pkgs.opencode-v2}/bin/opencode2 serve";
  opencodeV2LaunchdLabel = "org.nix-community.home.opencode2";
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

      home.file.".config/opencode/opencode-warden.json".text = builtins.toJSON {
        audit.filePath = "${config.home.homeDirectory}/.local/state/opencode/warden/audit.log";
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
        lib.optional pkgs.stdenv.isLinux {
          assertion =
            config.systemd.user.enable
            && lib.all (
              variable: lib.elem variable config.systemd.user.services.opencode2.Service.Environment
            ) mkV2SystemdEnvironment
            && lib.elem opencodeV2ServiceCommand config.systemd.user.services.opencode2.Service.ExecStart
            && config.systemd.user.services.opencode2.Service.Restart == "on-failure";
          message = "OpenCode V2 must run under a systemd user service with the shared V2 environment.";
        }
        ++ lib.optional pkgs.stdenv.isDarwin {
          assertion =
            config.launchd.agents.opencode2.enable
            &&
              config.launchd.agents.opencode2.config.ProgramArguments == [
                "${pkgs.opencode-v2}/bin/opencode2"
                "serve"
              ]
            && config.launchd.agents.opencode2.config.EnvironmentVariables == mkV2Environment
            && config.launchd.agents.opencode2.config.KeepAlive.Crashed
            && !config.launchd.agents.opencode2.config.KeepAlive.SuccessfulExit
            && config.launchd.agents.opencode2.config.RunAtLoad;
          message = "OpenCode V2 must run under a launchd agent with the shared V2 environment.";
        }
        ++ [
          {
            assertion =
              config.home.file.${opencodeV2EnvironmentFile}.text == mkV2ShellEnvironment
              && !lib.hasInfix "opencode2 service restart" config.home.activation.restartOpencodeV2.data;
            message = "OpenCode V2 wrappers and activation must use the shared environment and supervisor restart.";
          }
        ];

      systemd.user.enable = lib.mkIf pkgs.stdenv.isLinux true;

      systemd.user.services.opencode2 = lib.mkIf pkgs.stdenv.isLinux {
        Unit = {
          Description = "OpenCode V2 server";
          After = [ "default.target" ];
        };
        Service = {
          Type = "simple";
          Environment = mkV2SystemdEnvironment;
          ExecStart = opencodeV2ServiceCommand;
          Restart = "on-failure";
          RestartSec = "5s";
        };
        Install.WantedBy = [ "default.target" ];
      };

      launchd.agents.opencode2 = lib.mkIf pkgs.stdenv.isDarwin {
        enable = true;
        config = {
          ProgramArguments = [
            "${pkgs.opencode-v2}/bin/opencode2"
            "serve"
          ];
          EnvironmentVariables = mkV2Environment;
          KeepAlive = {
            Crashed = true;
            SuccessfulExit = false;
          };
          ProcessType = "Background";
          RunAtLoad = true;
        };
      };

      home.activation.restartOpencodeV2 = config.lib.dag.entryAfter [ "makeOpencodeConfigMutable-v2" ] ''
        runtime_root=${lib.escapeShellArg v2.runtimeRoot}
        config_file="${config.home.homeDirectory}/.config/opencode-v2/opencode.json"
        stamp="$runtime_root/opencode.json.activation"

        mkdir -p "$runtime_root"
        if [ ! -f "$stamp" ] || ! ${pkgs.diffutils}/bin/cmp -s "$config_file" "$stamp"; then
          if ! ${
            if pkgs.stdenv.isLinux then
              "${pkgs.systemd}/bin/systemctl --user restart opencode2"
            else
              "/bin/launchctl kickstart -k gui/\"$(${pkgs.coreutils}/bin/id -u)\"/${opencodeV2LaunchdLabel}"
          }; then
            echo "restartOpencodeV2: supervisor restart failed" >&2
            exit 1
          fi
          ${pkgs.coreutils}/bin/cp "$config_file" "$stamp"
        fi
      '';
    })
  ];
}
