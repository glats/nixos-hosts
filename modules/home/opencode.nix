{ config
, lib
, pkgs
, inputs
, ...
}:

with lib;

let
  # Import centralized provider configuration
  providers = import ./providers.nix { inherit lib; };

  # Pure library functions - no config references
  opencodeLib = import ../../pkgs/opencode-config {
    inherit lib;
    writeText = pkgs.writeText;
  };

  # Single runtime configuration
  runtimeConfig = {
    dir = "opencode";
    label = "default";
  };

  # Helper to generate config for the runtime
  mkRuntimeConfig =
    cfg: runtimeCfg:
    let
      runtimeDir = "${config.home.homeDirectory}/.config/${runtimeCfg.dir}";

      # Filter MCPs based on enabled field in each MCP config
      enabledMcps = lib.filterAttrs (name: mcp: mcp.enabled or false) cfg.mcps;

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

      # NVIDIA NIM provider block for opencode.json
      # apiKey uses OpenCode's {env:VAR} syntax — resolved at runtime, never stored in Nix store
      nvidiaProvider = {
        nvidia = {
          npm = "@ai-sdk/openai-compatible";
          name = "NVIDIA NIM";
          options = {
            baseURL = "https://integrate.api.nvidia.com/v1";
            apiKey = "{env:NVIDIA_API_KEY}";
            headers = {
              "Authorization" = "Bearer {env:NVIDIA_API_KEY}";
            };
          };
          models = {
            "z-ai/glm-5.1" = { name = "GLM 5.1"; };
            "minimaxai/minimax-m2.7" = { name = "MiniMax M2.7"; };
            "deepseek-ai/deepseek-v4-flash" = { name = "DeepSeek V4 Flash"; };
            "deepseek-ai/deepseek-v4-pro" = { name = "DeepSeek V4 Pro"; };
            "nvidia/nemotron-3-super-120b-a12b" = { name = "Nemotron 3 Super"; };
          };
        };
      };

      # Generate JSON file with providers and experimental fallback chain config
      # Note: generateOpencodeJson doesn't support experimental/plugin, so we generate directly
      jsonFile = pkgs.writeText "opencode.json" (
        builtins.toJSON {
          agent = cfg.agents;
          provider = nvidiaProvider;
          mcp = enabledMcps;
          permission = cfg.permissions;
          plugin = ["opencode-model-fallback-chain"];
          experimental = {
            modelFallbackChain = {
              timeoutMs = 60000;
              chains = [
                ["nvidia/deepseek-ai/deepseek-v4-pro" "nvidia/z-ai/glm-5.1"]
                ["nvidia/deepseek-ai/deepseek-v4-flash" "nvidia/minimaxai/minimax-m2.7"]
                ["nvidia/z-ai/glm-5.1" "nvidia/minimaxai/minimax-m2.7"]
                ["nvidia/minimaxai/minimax-m2.7" "nvidia/z-ai/glm-5.1"]
              ];
            };
          };
        }
      );
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
              "opencode-model-fallback-chain" = "*";
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
  };

  config = mkMerge [
    # Main configuration
    (mkIf config.home.opencode.enable {
      home.packages = with pkgs; [
        gentle-ai
        engram
      ];

      # Export NVIDIA API key from sops secret file at shell startup
      # Required for OpenCode's {env:NVIDIA_API_KEY} provider resolution
      programs.zsh.initContent = lib.mkAfter ''
        if [ -f "${config.sops.secrets."opencode/nvidia_api_key".path}" ]; then
          export NVIDIA_API_KEY="$(cat ${config.sops.secrets."opencode/nvidia_api_key".path})"
        fi
      '';
    })

    # Single runtime configuration
    (mkIf config.home.opencode.enable (
      mkRuntimeConfig config.home.opencode runtimeConfig
    ))
  ];
}
