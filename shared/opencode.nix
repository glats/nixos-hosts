{ config
, lib
, pkgs
, inputs
, ...
}:

with lib;

let
  # Import centralized provider configuration
  providers = import ./opencode/providers.nix { inherit lib; };

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

  # Single runtime configuration
  runtimeConfig = {
    dir = "opencode";
    label = "default";
  };

  mkRuntimeConfig = import ./opencode/runtime-config.nix;
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
      default = concatMap
        (server: map (tool: "${server}_${tool}") githubRareTools)
        [
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

      home.sessionVariables.RTK_TELEMETRY_DISABLED = "1";

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
      inherit runtimeConfig;
    }))
  ];
}
