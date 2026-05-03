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

      # TUI plugins configuration (name -> enabled)
      # Versions come from pkgs.opencode-npm-packages/versions.json
      tuiPluginsConfig = {
        "opencode-subagent-statusline" = {
          enable = cfg.tuiPlugins.subAgentStatusline.enable;
        };
        "opencode-sdd-engram-manage" = {
          enable = cfg.tuiPlugins.sddEngramManage.enable;
        };
      };
      tuiPluginsToInstall = lib.filterAttrs (name: cfg: cfg.enable) tuiPluginsConfig;

      # Use providers from centralized providers.nix
      allProviders = providers.allProviders;

      # Generate JSON file with providers and experimental fallback chain config
      # Note: generateOpencodeJson doesn't support experimental/plugin, so we generate directly
      jsonFile = pkgs.writeText "opencode.json" (
        builtins.toJSON {
          agent = cfg.agents;
          provider = allProviders;
          mcp = enabledMcps;
          permission = cfg.permissions;
        }
      );
    in
    {
      # HM creates symlinks here; makeOpencodeConfigMutable converts them to real copies at activation time.
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
        # skills/ and commands/ are managed entirely by makeOpencodeConfigMutable activation
        # (not via home.file) because HM cannot overwrite existing real directories with symlinks
        ".config/${runtimeCfg.dir}/package.json" = {
          force = true;
          source = "${pkgs.opencode-npm-packages}/package.json";
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

      # Convert HM symlinks to real files so OpenCode can write config at runtime.
      # NixOS symlink farm changes store paths on every rebuild; real copies avoid
      # false "config changed" signals that cause OpenCode to re-initialize.
      home.activation."makeOpencodeConfigMutable-${runtimeCfg.label}" =
        config.lib.dag.entryAfter [ "linkGeneration" ]
          ''
            runtime_dir="${runtimeDir}"

            if [ ! -d "$runtime_dir" ]; then
              exit 0
            fi

            # Single-file symlinks -> real copies (hash guard via cmp)
            for file in opencode.json IDENTITY.md SYSTEM_RULES.md PERSONA.md AGENTS.md package.json .gitignore tui.json; do
              target="$runtime_dir/$file"
              if [ -L "$target" ]; then
                src="$(${pkgs.coreutils}/bin/readlink -f "$target")"
                if [ ! -f "$target" ] || ! ${pkgs.coreutils}/bin/cmp -s "$src" "$target"; then
                  ${pkgs.coreutils}/bin/cp --remove-destination "$src" "$target"
                fi
              fi
              # Ensure files are writable (nix store sources are read-only)
              if [ -f "$target" ] && [ ! -w "$target" ]; then
                chmod 644 "$target"
              fi
            done

            # Directory management for skills/ and commands/
            # Handled here (not via home.file) because HM cannot overwrite real dirs with symlinks.
            # Copies files from nix store with per-file cmp guard + orphan removal.
            for dir_pair in "skills:${pkgs.gentle-ai-assets}/share/gentle-ai/skills" "commands:${pkgs.gentle-ai-assets}/share/gentle-ai/opencode/commands"; do
              dir_name="''${dir_pair%%:*}"
              src="''${dir_pair#*:}"
              target="$runtime_dir/$dir_name"
              # Remove symlink if HM managed to create one
              if [ -L "$target" ]; then
                ${pkgs.coreutils}/bin/rm -f "$target"
              fi
              mkdir -p "$target"
              # Copy changed files
              (cd "$src" && ${pkgs.findutils}/bin/find . -type f) | while read -r rel; do
                if [ ! -f "$target/$rel" ] || ! ${pkgs.coreutils}/bin/cmp -s "$src/$rel" "$target/$rel"; then
                  mkdir -p "$(dirname "$target/$rel")"
                  ${pkgs.coreutils}/bin/cp -f "$src/$rel" "$target/$rel"
                  chmod 644 "$target/$rel"
                fi
              done
              # Remove orphaned files
              (cd "$target" && ${pkgs.findutils}/bin/find . -type f) | while read -r rel; do
                if [ ! -f "$src/$rel" ]; then
                  rm -f "$target/$rel"
                fi
              done
            done
          '';

      # Install plugins and npm deps; runs after symlink conversion.
      home.activation."setupOpencodePluginRuntime-${runtimeCfg.label}" =
        config.lib.dag.entryAfter [ "makeOpencodeConfigMutable-${runtimeCfg.label}" ]
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

            # Copy plugin files from nix store (not symlinks) with hash guard
            ${lib.optionalString cfg.plugins.engram.enable ''
              target="$runtime_dir/plugins/engram.ts"
              src="${pkgs.engram-assets}/share/engram/opencode/plugins/engram.ts"
              if [ ! -f "$target" ] || ! ${pkgs.coreutils}/bin/cmp -s "$src" "$target"; then
                ${pkgs.coreutils}/bin/cp -f "$src" "$target"
                chmod 644 "$target"
              fi
            ''}
            ${lib.optionalString cfg.plugins.backgroundAgents.enable ''
              target="$runtime_dir/plugins/background-agents.ts"
              src="${pkgs.gentle-ai-assets}/share/gentle-ai/opencode/plugins/background-agents.ts"
              if [ ! -f "$target" ] || ! ${pkgs.coreutils}/bin/cmp -s "$src" "$target"; then
                ${pkgs.coreutils}/bin/cp -f "$src" "$target"
                chmod 644 "$target"
              fi
            ''}

            # Copy npm packages from Nix store (pre-built, hash-verified)
            mkdir -p "$runtime_dir/node_modules"
            cp -r ${pkgs.opencode-npm-packages}/lib/node_modules/* "$runtime_dir/node_modules/"
            chmod -R u+w "$runtime_dir/node_modules"

            # Install TUI plugins: all are already in node_modules from Nix derivation
            # OpenCode picks them up from tui.json plugin list

            # Workaround for opencode bug: migration gate checks for opencode.db
            # but non-latest channels (stable) use opencode-stable.db, causing
            # migration to re-run on every launch. Symlink stable -> default name.
            # See: https://github.com/anomalyco/opencode/issues/16885
            data_dir="${config.home.homeDirectory}/.local/share/opencode"
            if [ -f "$data_dir/opencode-stable.db" ] && [ ! -e "$data_dir/opencode.db" ]; then
              ln -s "$data_dir/opencode-stable.db" "$data_dir/opencode.db"
            fi
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
      '';
    })

    # Single runtime configuration
    (mkIf config.home.opencode.enable (
      mkRuntimeConfig config.home.opencode runtimeConfig
    ))
  ];
}
