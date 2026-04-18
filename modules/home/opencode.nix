{ config, pkgs, inputs, ... }:

let
  opencodeConfigDir = "${config.home.homeDirectory}/.config/opencode";
  fireworksKeyPath = config.sops.secrets."opencode/fireworks_api_key".path;
  
  # Referencia al gentle-ai-src desde los inputs del flake
  gentle-ai-src = inputs.gentle-ai-src;
in

{
  # SDD structure (skills, commands, plugins) - LOCAL por ahora
  # TODO: Migrar a upstream cuando gentle-ai-src tenga caveman completo
  home.file.".config/opencode/PERSONA.md".source = ./opencode/PERSONA.md;
  home.file.".config/opencode/skills".source = ./opencode/skills;
  home.file.".config/opencode/commands".source = ./opencode/commands;
  home.file.".config/opencode/plugins".source = ./opencode/plugins;

  # Immutable TUI configuration
  home.file.".config/opencode/tui.json".text = ''
    {
      "$schema": "https://opencode.ai/tui.json",
      "theme": "system"
    }
  '';

  # Always sync opencode.json from base on every rebuild (declarative config)
  # Injects Fireworks API key from sops secret
  home.activation.setupOpencodeConfig = config.lib.dag.entryAfter [ "writeBoundary" ] ''
    _i "Setting up OpenCode configuration directory"
    mkdir -p ${opencodeConfigDir}

    # Read API key from sops secret
    FIREWORKS_KEY=$(${pkgs.coreutils}/bin/cat ${fireworksKeyPath})

    # Sync from base and inject the API key
    _i "Syncing opencode.json from base configuration"
    ${pkgs.coreutils}/bin/cp ${./opencode/opencode.json.base} ${opencodeConfigDir}/opencode.json
    ${pkgs.gnused}/bin/sed -i "s|FIREWORKS_API_KEY_PLACEHOLDER|$FIREWORKS_KEY|g" ${opencodeConfigDir}/opencode.json
    ${pkgs.coreutils}/bin/chmod u+rw ${opencodeConfigDir}/opencode.json
  '';

  home.packages = with pkgs; [
    gentle-ai
    engram
  ];
}
