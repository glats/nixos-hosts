# OpenCode Legacy Configuration Module
# This is the activation-script based configuration used before the
# declarative build-time generation approach.
#
# DEPRECATED: This module is kept as a fallback during migration.
# Use modules/home/opencode/ (the new module) for the declarative configuration.
#
# Migration path:
# 1. Test new module with: imports = [ ./opencode.nix ]; home.opencode.enable = true;
# 2. Set home.opencode.runtime = "lab" to test without affecting stable
# 3. Once satisfied, switch to runtime = "stable"
# 4. Remove this legacy module import

{ config, pkgs, inputs, ... }:

let
  opencodeConfigDir = "${config.home.homeDirectory}/.config/opencode";
  fireworksKeyPath = config.sops.secrets."opencode/fireworks_api_key".path;
  deepinfraKeyPath = config.sops.secrets."opencode/deepinfra_api_key".path;
  anthropicKeyPath = config.sops.secrets."opencode/anthropic_api_key".path;
  openaiKeyPath = config.sops.secrets."opencode/openai_api_key".path;

  # Assets from gentle-ai upstream (via derivation)
  gentle-ai-assets = pkgs.gentle-ai-assets;
in

{
  # LEGACY ACTIVATION SCRIPT - Uses sed injection at activation time
  # This is the old method that we're migrating away from.
  # Prefer the new declarative modules/home/opencode.nix instead.

  home.file.".config/opencode/PERSONA.md".source = "${gentle-ai-assets}/share/gentle-ai/opencode/persona-gentleman.md";
  home.file.".config/opencode/AGENTS.md".source = "${gentle-ai-assets}/share/gentle-ai/AGENTS.md";
  home.file.".config/opencode/skills".source = "${gentle-ai-assets}/share/gentle-ai/skills";
  home.file.".config/opencode/commands".source = "${gentle-ai-assets}/share/gentle-ai/opencode/commands";

  home.file.".config/opencode/tui.json".text = ''
    {
      "$schema": "https://opencode.ai/tui.json",
      "theme": "system"
    }
  '';

  # ACTIVATION SCRIPT - Copies base JSON and injects API keys via sed
  home.activation.setupOpencodeConfig = config.lib.dag.entryAfter [ "writeBoundary" ] ''
    _i "Setting up OpenCode configuration directory (legacy mode)"
    mkdir -p ${opencodeConfigDir}

    # Read API keys from sops secrets
    FIREWORKS_KEY=$(${pkgs.coreutils}/bin/cat ${fireworksKeyPath})
    DEEPINFRA_KEY=$(${pkgs.coreutils}/bin/cat ${deepinfraKeyPath})
    ANTHROPIC_KEY=$(${pkgs.coreutils}/bin/cat ${anthropicKeyPath})
    OPENAI_KEY=$(${pkgs.coreutils}/bin/cat ${openaiKeyPath})

    # Sync from base and inject the API keys
    _i "Syncing opencode.json from base configuration"
    ${pkgs.coreutils}/bin/cp ${./opencode/opencode.json.base} ${opencodeConfigDir}/opencode.json
    ${pkgs.gnused}/bin/sed -i "s|FIREWORKS_API_KEY_PLACEHOLDER|$FIREWORKS_KEY|g" ${opencodeConfigDir}/opencode.json
    ${pkgs.gnused}/bin/sed -i "s|DEEPINFRA_API_KEY_PLACEHOLDER|$DEEPINFRA_KEY|g" ${opencodeConfigDir}/opencode.json
    ${pkgs.gnused}/bin/sed -i "s|ANTHROPIC_API_KEY_PLACEHOLDER|$ANTHROPIC_KEY|g" ${opencodeConfigDir}/opencode.json
    ${pkgs.gnused}/bin/sed -i "s|OPENAI_API_KEY_PLACEHOLDER|$OPENAI_KEY|g" ${opencodeConfigDir}/opencode.json
    ${pkgs.coreutils}/bin/chmod u+rw ${opencodeConfigDir}/opencode.json
  '';

  home.packages = with pkgs; [
    gentle-ai
    engram
  ];
}
