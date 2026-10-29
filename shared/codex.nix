{
  config,
  lib,
  ...
}:

{
  imports = [ ./ai-assets.nix ];

  options.home.codex.enable = lib.mkEnableOption "Codex global rules, shared skills and tools";

  config = lib.mkIf config.home.codex.enable {
    home.ai-assets.enable = true;
    home.file.".codex/AGENTS.md".text = lib.concatMapStringsSep "\n\n" builtins.readFile (
      config.home.ai-assets.ruleSources ++ config.home.ai-assets.agentsMdSources
    );
  };
}
