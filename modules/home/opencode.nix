{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:

with lib;

let
  # Pure library functions - no config references
  opencodeLib = import ../../pkgs/opencode-config {
    inherit lib;
    writeText = pkgs.writeText;
  };

  # Static runtime configs
  runtimeConfigs = {
    stable = {
      dir = "opencode";
      label = "stable";
    };
    lab = {
      dir = "opencode-lab";
      label = "lab";
    };
  };

  # Helper to generate config for a specific runtime
  mkRuntimeConfig =
    cfg: runtimeName: runtimeCfg:
    let
      runtimeDir = "${config.home.homeDirectory}/.config/${runtimeCfg.dir}";

      # Filter MCPs based on toggles
      enabledMcps = lib.filterAttrs (
        name: mcp:
        (name == "github" && cfg.mcpToggles.github)
        || (name == "nixos" && cfg.mcpToggles.nixos)
        || (name == "context7" && cfg.mcpToggles.context7)
        || (name == "engram" && cfg.mcpToggles.engram)
        || (name == "exa" && cfg.mcpToggles.exa)
      ) cfg.mcps;

      # TUI plugins configuration (name -> version)
      tuiPluginsConfig = {
        "opencode-subagent-statusline" = {
          version = "0.4.1";
          enable = cfg.tuiPlugins.subAgentStatusline.enable;
        };
        "opencode-sdd-engram-manage" = {
          version = "1.2.0";
          enable = cfg.tuiPlugins.sddEngramManage.enable;
        };
      };
      tuiPluginsToInstall = lib.filterAttrs (name: cfg: cfg.enable) tuiPluginsConfig;

      # Generate JSON file with empty providers (OAuth via /connect)
      jsonFile = opencodeLib.generateOpencodeJson {
        agents = cfg.agents;
        providers = { }; # OAuth-based providers - no static config needed
        mcps = enabledMcps;
        permissions = cfg.permissions;
      };
    in
    {
      home.file = {
        ".config/${runtimeCfg.dir}/opencode.json" = {
          force = true;
          source = jsonFile;
        };
        ".config/${runtimeCfg.dir}/IDENTITY.md".source = ./opencode/IDENTITY.md;
        ".config/${runtimeCfg.dir}/SYSTEM_RULES.md".source = ./opencode/SYSTEM_RULES.md;
        ".config/${runtimeCfg.dir}/PERSONA.md".text = ''
          ${builtins.readFile ./opencode/IDENTITY.md}

          ${builtins.readFile ./opencode/SYSTEM_RULES.md}
        '';
        ".config/${runtimeCfg.dir}/AGENTS.md".source = "${pkgs.gentle-ai-assets}/share/gentle-ai/AGENTS.md";
        ".config/${runtimeCfg.dir}/skills".source = "${pkgs.gentle-ai-assets}/share/gentle-ai/skills";
        ".config/${runtimeCfg.dir}/commands".source =
          "${pkgs.gentle-ai-assets}/share/gentle-ai/opencode/commands";
        ".config/${runtimeCfg.dir}/package.json" = {
          force = true;
          text = builtins.toJSON {
            dependencies = {
              "@opencode-ai/plugin" = "1.4.11";
              "@opencode-ai/sdk" = "1.4.11";
              "unique-names-generator" = "^4.7.1";
            };
          };
        };
        ".config/${runtimeCfg.dir}/.gitignore" = {
          force = true;
          text = ''
            node_modules
            package-lock.json
            bun.lock
          '';
        };
        ".config/${runtimeCfg.dir}/tui.json".text = builtins.toJSON {
          "$schema" = "https://opencode.ai/tui.json";
          theme = "system";
          plugin = lib.attrNames tuiPluginsToInstall;
        };
        # Plugin .ts files are copied by activation script below, not as symlinks
      };

      home.activation."setupOpencodePluginRuntime-${runtimeCfg.label}" =
        config.lib.dag.entryAfter [ "writeBoundary" ]
          ''
            runtime_dir="${runtimeDir}"

            if [ ! -d "$runtime_dir" ]; then
              exit 0
            fi

            # Ensure plugins directory is a real directory (not symlink)
            if [ -L "$runtime_dir/plugins" ]; then
              ${pkgs.coreutils}/bin/rm -f "$runtime_dir/plugins"
            fi
            mkdir -p "$runtime_dir/plugins"

            # Copy plugin files from nix store (not symlinks)
            ${lib.optionalString cfg.plugins.engram.enable ''
              ${pkgs.coreutils}/bin/cp -f "${pkgs.engram-assets}/share/engram/opencode/plugins/engram.ts" "$runtime_dir/plugins/engram.ts"
            ''}
            ${lib.optionalString cfg.plugins.backgroundAgents.enable ''
              ${pkgs.coreutils}/bin/cp -f "${pkgs.gentle-ai-assets}/share/gentle-ai/opencode/plugins/background-agents.ts" "$runtime_dir/plugins/background-agents.ts"
            ''}

            # Install npm dependencies for plugins
            export HOME="${config.home.homeDirectory}"
            ${pkgs.nodejs}/bin/npm install --prefix "$runtime_dir" --no-save \
              @opencode-ai/plugin@1.4.11 \
              @opencode-ai/sdk@1.4.11 \
              unique-names-generator@^4.7.1 >/dev/null 2>&1 || true

            # Install TUI plugins based on enabled options
            ${lib.optionalString cfg.tuiPlugins.subAgentStatusline.enable ''
              ${pkgs.nodejs}/bin/npm install --prefix "$runtime_dir" --no-save \
                opencode-subagent-statusline@0.4.1 >/dev/null 2>&1 || true
            ''}
            ${lib.optionalString cfg.tuiPlugins.sddEngramManage.enable ''
              ${pkgs.nodejs}/bin/npm install --prefix "$runtime_dir" --no-save \
                opencode-sdd-engram-manage@1.2.0 >/dev/null 2>&1 || true
            ''}
          '';
    };
in
{
  imports = [
    ./opencode/agents.nix
    ./opencode/mcps.nix
    ./opencode/permissions.nix
    ./opencode/plugins.nix
  ];

  options.home.opencode = {
    enable = mkEnableOption "OpenCode configuration with declarative JSON generation";

    runtime = mkOption {
      type = types.enum [
        "stable"
        "lab"
        "both"
      ];
      default = "stable";
      description = ''
        Runtime mode for OpenCode:
        - stable: Use ~/.config/opencode/ (default, production)
        - lab: Use ~/.config/opencode-lab/ (experimental, isolated)
        - both: Generate both configurations simultaneously
      '';
    };
  };

  config = mkMerge [
    # Main configuration
    (mkIf config.home.opencode.enable {
      home.packages = with pkgs; [
        gentle-ai
        engram
      ];
    })

    # Stable runtime configuration
    (mkIf (
      config.home.opencode.enable
      && (config.home.opencode.runtime == "stable" || config.home.opencode.runtime == "both")
    ) (mkRuntimeConfig config.home.opencode "stable" runtimeConfigs.stable))

    # Lab runtime configuration
    (mkIf (
      config.home.opencode.enable
      && (config.home.opencode.runtime == "lab" || config.home.opencode.runtime == "both")
    ) (mkRuntimeConfig config.home.opencode "lab" runtimeConfigs.lab))
  ];
}
