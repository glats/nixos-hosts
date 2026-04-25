{ config, lib, pkgs, inputs, ... }:

with lib;

let
  # Pure library functions - no config references
  opencodeLib = import ../../pkgs/opencode-config { inherit lib; writeText = pkgs.writeText; };

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
  mkRuntimeConfig = cfg: runtimeName: runtimeCfg:
    let
      runtimeDir = "${config.home.homeDirectory}/.config/${runtimeCfg.dir}";

      # Filter MCPs based on toggles
      enabledMcps = lib.filterAttrs
        (name: mcp:
          (name == "github" && cfg.mcpToggles.github) ||
          (name == "nixos" && cfg.mcpToggles.nixos) ||
          (name == "context7" && cfg.mcpToggles.context7) ||
          (name == "engram" && cfg.mcpToggles.engram)
        )
        cfg.mcps;

      # Generate JSON file with placeholder API keys; activation script will
      # replace them with real secret values in the mutable runtime file.
      jsonFile = opencodeLib.generateOpencodeJson {
        agents = cfg.agents;
        providers = cfg.providers;
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
        ".config/${runtimeCfg.dir}/PERSONA.md".source = "${pkgs.gentle-ai-assets}/share/gentle-ai/opencode/persona-gentleman.md";
        ".config/${runtimeCfg.dir}/AGENTS.md".source = "${pkgs.gentle-ai-assets}/share/gentle-ai/AGENTS.md";
        ".config/${runtimeCfg.dir}/skills".source = "${pkgs.gentle-ai-assets}/share/gentle-ai/skills";
        ".config/${runtimeCfg.dir}/commands".source = "${pkgs.gentle-ai-assets}/share/gentle-ai/opencode/commands";
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
        ".config/${runtimeCfg.dir}/tui.json".text = ''
          {
            "$schema": "https://opencode.ai/tui.json",
            "theme": "system"
          }
        '';
        # Plugin .ts files are copied by activation script below, not as symlinks
      };

      home.activation."setupOpencodePluginRuntime-${runtimeCfg.label}" = config.lib.dag.entryAfter [ "writeBoundary" ] ''
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
          ${pkgs.coreutils}/bin/cp -f "${./opencode/plugins/engram.ts}" "$runtime_dir/plugins/engram.ts"
        ''}
        ${lib.optionalString cfg.plugins.backgroundAgents.enable ''
          ${pkgs.coreutils}/bin/cp -f "${./opencode/plugins/background-agents.ts}" "$runtime_dir/plugins/background-agents.ts"
        ''}

        # Install npm dependencies for plugins
        export HOME="${config.home.homeDirectory}"
        ${pkgs.nodejs}/bin/npm install --prefix "$runtime_dir" --no-save \
          @opencode-ai/plugin@1.4.11 \
          @opencode-ai/sdk@1.4.11 \
          unique-names-generator@^4.7.1 >/dev/null 2>&1 || true
      '';

      home.activation."setupOpencodeSecrets-${runtimeCfg.label}" = config.lib.dag.entryAfter [ "sops-nix" ] ''
        runtime_dir="${runtimeDir}"
        config_file="$runtime_dir/opencode.json"

        if [ ! -e "$config_file" ]; then
          exit 0
        fi

        tmp_json="$runtime_dir/.opencode.json.tmp"
        ${pkgs.coreutils}/bin/cp --dereference "$config_file" "$tmp_json"

        if [ -f "${cfg.providerSecrets.fireworks or ""}" ]; then
          FIREWORKS_KEY=$(${pkgs.coreutils}/bin/cat "${cfg.providerSecrets.fireworks or ""}")
          ${pkgs.gnused}/bin/sed -i "s|FIREWORKS_API_KEY_PLACEHOLDER|$FIREWORKS_KEY|g" "$tmp_json"
        fi

        if [ -f "${cfg.providerSecrets.deepinfra or ""}" ]; then
          DEEPINFRA_KEY=$(${pkgs.coreutils}/bin/cat "${cfg.providerSecrets.deepinfra or ""}")
          ${pkgs.gnused}/bin/sed -i "s|DEEPINFRA_API_KEY_PLACEHOLDER|$DEEPINFRA_KEY|g" "$tmp_json"
        fi

        if [ -f "${cfg.providerSecrets.anthropic or ""}" ]; then
          ANTHROPIC_KEY=$(${pkgs.coreutils}/bin/cat "${cfg.providerSecrets.anthropic or ""}")
          ${pkgs.gnused}/bin/sed -i "s|ANTHROPIC_API_KEY_PLACEHOLDER|$ANTHROPIC_KEY|g" "$tmp_json"
        fi

        if [ -f "${cfg.providerSecrets.openai or ""}" ]; then
          OPENAI_KEY=$(${pkgs.coreutils}/bin/cat "${cfg.providerSecrets.openai or ""}")
          ${pkgs.gnused}/bin/sed -i "s|OPENAI_API_KEY_PLACEHOLDER|$OPENAI_KEY|g" "$tmp_json"
        fi

        ${pkgs.coreutils}/bin/rm -f "$config_file"
        ${pkgs.coreutils}/bin/mv "$tmp_json" "$config_file"
      '';
    };
in
{
  imports = [
    ./opencode/agents.nix
    ./opencode/providers.nix
    ./opencode/mcps.nix
    ./opencode/permissions.nix
    ./opencode/plugins.nix
  ];

  options.home.opencode = {
    enable = mkEnableOption "OpenCode configuration with declarative JSON generation";

    runtime = mkOption {
      type = types.enum [ "stable" "lab" "both" ];
      default = "stable";
      description = ''
        Runtime mode for OpenCode:
        - stable: Use ~/.config/opencode/ (default, production)
        - lab: Use ~/.config/opencode-lab/ (experimental, isolated)
        - both: Generate both configurations simultaneously

        Migration Guide:
        1. Start with `runtime = "lab"` to test without affecting production
        2. Test: `OPENCODE_CONFIG_DIR=~/.config/opencode-lab opencode`
        3. Once satisfied, switch to `runtime = "stable"` (replaces legacy)
        4. Disable legacy fallback: `legacyFallback = false`
      '';
    };

    legacyFallback = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Enable legacy fallback during migration period.

        When true (default), both the new declarative module AND the legacy
        activation-script module can coexist. The legacy module provides a
        rollback path if issues are encountered.

        Migration steps:
        1. Set `enable = true` and `runtime = "lab"` to test new module
        2. Verify lab runtime works: `OPENCODE_CONFIG_DIR=~/.config/opencode-lab opencode`
        3. Switch to `runtime = "stable"` (replaces ~/.config/opencode/)
        4. After 2 weeks of stable operation, set `legacyFallback = false`
        5. Eventually remove `legacyFallback` option entirely

        To rollback: Switch imports from `opencode.nix` back to `opencode-legacy.nix`
      '';
    };
  };

  config = mkMerge [
    # Migration warning when new module is enabled with legacy fallback
    (mkIf (config.home.opencode.enable && config.home.opencode.legacyFallback) {
      warnings = [
        ("OpenCode: New declarative module is enabled with legacyFallback=true. " +
          "This is the migration state. After testing with runtime='lab', " +
          "switch to runtime='stable' and eventually set legacyFallback=false. " +
          "See home.opencode.runtime description for full migration steps.")
      ];
    })

    # Main configuration
    (mkIf config.home.opencode.enable {
      home.packages = with pkgs; [ gentle-ai engram ];
    })

    # Stable runtime configuration
    (mkIf (config.home.opencode.enable && (config.home.opencode.runtime == "stable" || config.home.opencode.runtime == "both")) (
      mkRuntimeConfig config.home.opencode "stable" runtimeConfigs.stable
    ))

    # Lab runtime configuration
    (mkIf (config.home.opencode.enable && (config.home.opencode.runtime == "lab" || config.home.opencode.runtime == "both")) (
      mkRuntimeConfig config.home.opencode "lab" runtimeConfigs.lab
    ))
  ];
}
