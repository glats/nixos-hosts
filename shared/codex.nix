{
  config,
  lib,
  ...
}:

{
  imports = [ ./ai-assets.nix ];

  options.home.codex.enable = lib.mkEnableOption "Codex global AGENTS.md with the shared user rules";

  config = lib.mkIf config.home.codex.enable {
    home.file.".codex/AGENTS.md".text = lib.concatMapStringsSep "\n\n" builtins.readFile (
      config.home.ai-assets.ruleSources ++ config.home.ai-assets.agentsMdSources
    );
  };
}
