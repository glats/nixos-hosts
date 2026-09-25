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
  mkV2Environment = lib.concatStringsSep "\n" (
    lib.mapAttrsToList (name: value: "export ${name}=${lib.escapeShellArg value}") {
      XDG_CONFIG_HOME = "${config.home.homeDirectory}/.config/opencode-v2";
      XDG_DATA_HOME = "${v2.runtimeRoot}/data";
      XDG_CACHE_HOME = "${v2.runtimeRoot}/cache";
      XDG_STATE_HOME = "${v2.runtimeRoot}/state";
      OPENCODE_CONFIG_DIR = "${config.home.homeDirectory}/.config/opencode-v2";
      OPENCODE_DB = "${v2.runtimeRoot}/data/opencode.db";
      TMPDIR = "${v2.runtimeRoot}/tmp";
      OPENCODE_DISABLE_PROJECT_CONFIG = "1";
    }
  );
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

    disabledProviders = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = "Built-in providers to disable (e.g. cloudflare-workers-ai).";
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

      environment = mkOption {
        type = types.lines;
        readOnly = true;
        internal = true;
        default = mkV2Environment;
        description = "Complete version-scoped environment shared by OpenCode V2 wrappers and activation.";
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
              if [ -f "${config.sops.secrets."opencode/groq_api_key".path}" ]; then
                export GROQ_API_KEY="$(cat ${config.sops.secrets."opencode/groq_api_key".path})"
              fi
            if [ -f "${config.sops.secrets."opencode/cerebras_api_key".path}" ]; then
              export CEREBRAS_API_KEY="$(cat ${config.sops.secrets."opencode/cerebras_api_key".path})"
            fi
          if [ -f "${config.sops.secrets."opencode/opencode_go_api_key".path}" ]; then
            export OPENCODE_API_KEY="$(cat ${config.sops.secrets."opencode/opencode_go_api_key".path})"
          fi
            if [ -f "${config.sops.secrets."opencode/openrouter_api_key".path}" ]; then
              export OPENROUTER_API_KEY="$(cat ${config.sops.secrets."opencode/openrouter_api_key".path})"
            fi
          if [ -f "${config.sops.secrets."opencode/mistral_api_key".path}" ]; then
            export MISTRAL_API_KEY="$(cat ${config.sops.secrets."opencode/mistral_api_key".path})"
          fi
          if [ -f "${config.sops.secrets."opencode/cohere_api_key".path}" ]; then
            export COHERE_API_KEY="$(cat ${config.sops.secrets."opencode/cohere_api_key".path})"
          fi
          if [ -f "${config.sops.secrets."opencode/gemini_api_key".path}" ]; then
            export GEMINI_API_KEY="$(cat ${config.sops.secrets."opencode/gemini_api_key".path})"
          fi
        if [ -f "${config.sops.secrets."opencode/cloudflare_api_key".path}" ]; then
          export CLOUDFLARE_API_TOKEN="$(cat ${config.sops.secrets."opencode/cloudflare_api_key".path})"
        fi
        if [ -f "${config.sops.secrets."opencode/cloudflare_account_id".path}" ]; then
          export CLOUDFLARE_ACCOUNT_ID="$(cat ${config.sops.secrets."opencode/cloudflare_account_id".path})"
        fi
          if [ -f "${config.sops.secrets."opencode/huggingface_api_key".path}" ]; then
            export HF_API_KEY="$(cat ${config.sops.secrets."opencode/huggingface_api_key".path})"
          fi
          if [ -f "${config.sops.secrets."opencode/kilo_api_key".path}" ]; then
            export KILO_API_KEY="$(cat ${config.sops.secrets."opencode/kilo_api_key".path})"
          fi
          if [ -f "${config.sops.secrets."opencode/aihubmix_api_key".path}" ]; then
            export AIHUBMIX_API_KEY="$(cat ${config.sops.secrets."opencode/aihubmix_api_key".path})"
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
      home.activation.restartOpencodeV2 = config.lib.dag.entryAfter [ "makeOpencodeConfigMutable-v2" ] ''
        runtime_root=${lib.escapeShellArg v2.runtimeRoot}
        config_file="${config.home.homeDirectory}/.config/opencode-v2/opencode.json"
        stamp="$runtime_root/opencode.json.activation"

        mkdir -p "$runtime_root"
        if [ ! -f "$stamp" ] || ! ${pkgs.diffutils}/bin/cmp -s "$config_file" "$stamp"; then
          ${mkV2Environment}
          if ! ${pkgs.opencode-v2}/bin/opencode2 service restart; then
            echo "restartOpencodeV2: opencode2 service restart failed" >&2
            exit 1
          fi
          ${pkgs.coreutils}/bin/cp "$config_file" "$stamp"
        fi
      '';
    })
  ];
}
