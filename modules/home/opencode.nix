{ config, pkgs, inputs, ... }:

let
  opencodeConfigDir = "${config.home.homeDirectory}/.config/opencode";
  fireworksKeyPath = config.sops.secrets."opencode/fireworks_api_key".path;
  deepinfraKeyPath = config.sops.secrets."opencode/deepinfra_api_key".path;
  anthropicKeyPath = config.sops.secrets."opencode/anthropic_api_key".path;

  # Assets from gentle-ai upstream (via derivation)
  gentle-ai-assets = pkgs.gentle-ai-assets;
in

{
  # OpenCode configuration structure
  # NOTE: Uses derivation from pkgs/gentle-ai-assets for most files
  # PERSONA.md is local to allow custom rules
  home.file.".config/opencode/PERSONA.md".source = ./opencode/PERSONA.md;
  home.file.".config/opencode/AGENTS.md".source = "${gentle-ai-assets}/share/gentle-ai/AGENTS.md";
  home.file.".config/opencode/skills".source = "${gentle-ai-assets}/share/gentle-ai/skills";
  home.file.".config/opencode/commands".source = "${gentle-ai-assets}/share/gentle-ai/opencode/commands";
  # NOTE: Plugins intentionally omitted - background-agents causes orchestration issues
  # See: https://github.com/Gentleman-Programming/agent-teams-lite/issues/58

  # Immutable TUI configuration
  home.file.".config/opencode/tui.json".text = ''
    {
      "$schema": "https://opencode.ai/tui.json",
      "theme": "system"
    }
  '';

  # Always sync opencode.json from base on every rebuild (declarative config)
  # Injects API keys from sops secrets
  home.activation.setupOpencodeConfig = config.lib.dag.entryAfter [ "writeBoundary" ] ''
    _i "Setting up OpenCode configuration directory"
    mkdir -p ${opencodeConfigDir}

    # Read API keys from sops secrets
    FIREWORKS_KEY=$(${pkgs.coreutils}/bin/cat ${fireworksKeyPath})
    DEEPINFRA_KEY=$(${pkgs.coreutils}/bin/cat ${deepinfraKeyPath})
    ANTHROPIC_KEY=$(${pkgs.coreutils}/bin/cat ${anthropicKeyPath})

    # Sync from base and inject the API keys
    _i "Syncing opencode.json from base configuration"
    ${pkgs.coreutils}/bin/cp ${./opencode/opencode.json.base} ${opencodeConfigDir}/opencode.json
    ${pkgs.gnused}/bin/sed -i "s|FIREWORKS_API_KEY_PLACEHOLDER|$FIREWORKS_KEY|g" ${opencodeConfigDir}/opencode.json
    ${pkgs.gnused}/bin/sed -i "s|DEEPINFRA_API_KEY_PLACEHOLDER|$DEEPINFRA_KEY|g" ${opencodeConfigDir}/opencode.json
    ${pkgs.gnused}/bin/sed -i "s|ANTHROPIC_API_KEY_PLACEHOLDER|$ANTHROPIC_KEY|g" ${opencodeConfigDir}/opencode.json
    ${pkgs.coreutils}/bin/chmod u+rw ${opencodeConfigDir}/opencode.json
  '';

  home.packages = with pkgs; [
    gentle-ai
    engram
  ];
}
