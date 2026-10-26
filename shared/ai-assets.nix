{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

{
  imports = [
    ./ai-mcps.nix
    ./ai-tools.nix
  ];

  options.home.ai-assets = {
    enable = mkEnableOption "Gentle AI ecosystem assets";

    skillSources = mkOption {
      type = types.listOf types.path;
      default = [
        "${pkgs.gentle-ai-assets}/share/gentle-ai/skills"
        "${pkgs.caveman-assets}/share/caveman/skills"
        "${pkgs.ponytail-assets}/share/ponytail/skills"
        "${pkgs.local-ai-assets}/share/local-ai/skills"
      ];
      description = "Ordered skill source directories (later wins on conflict).";
    };

    ruleSources = mkOption {
      type = types.listOf types.path;
      default = [
        ./rules/authorization.md
        ./rules/explore-mcp.md
        ./rules/output-format.md
        ./rules/code-comments.md
      ];
      description = "User rules included in every harness's global prompt (OpenCode, Claude Code, Codex).";
    };

    agentsMdSources = mkOption {
      type = types.listOf types.path;
      default = [ ];
      description = "Extra global AGENTS.md/CLAUDE.md fragments appended after the managed prompt. Keep project facts in the project's own AGENTS.md.";
    };

    engramConfig = mkOption {
      type = types.attrsOf types.anything;
      default = { };
      description = "Engram configuration shared across Gentle AI tools.";
    };
  };

  config = mkIf config.home.ai-assets.enable {
    home.ai-tools.enable = true;
    home.sessionVariables.ARCHIFY_UPDATE_CHECK_DISABLED = "1";
  };
}
