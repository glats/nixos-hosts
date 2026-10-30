{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:

with lib;

let
  providers = import ./opencode/providers-base.nix {
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
          --set GPG_TTY "" \
          --set PINENTRY_USER_DATA opencode \
          --prefix PATH : ${
            lib.makeBinPath [
              gentleManaged
              pkgs.git
            ]
          }
      '';
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
        description = "Enable the pinned BrowserMCP server as a local MCP.";
      };
      package = mkOption {
        type = types.package;
        default = pkgs.browsermcp-v2;
        description = "Pinned BrowserMCP package.";
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

    quotaPlugin = mkOption {
      type = types.nullOr types.package;
      default = pkgs.callPackage ../pkgs/opencode-quota-patched { };
      description = ''
        Local opencode-quota plugin directory loaded instead of the npm
        `@slkiser/opencode-quota@5.0.3` spec. Defaults to the pinned package
        with passive Anthropic response-header quota. null keeps the npm spec.
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

      home.ai-tools.enable = true;
      home.ai-tools.gentlePackage = gentleManaged;
      home.packages = [ opencodePackage ];

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
      assetRevision = inputs.gentle-ai-src.rev;
    }))
  ];
}
