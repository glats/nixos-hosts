# Gentle AI ecosystem assets shared across all tools (OpenCode, Claude Code, etc.)
# Defines skill/command/AGENTS.md sources, MCPs, and Engram config — consumed by
# tool-specific modules.
{ config
, lib
, pkgs
, ...
}:

with lib;

{
  imports = [
    ./opencode/mcps-base.nix
    ./opencode/mcps.nix
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

    agentsMdSources = mkOption {
      type = types.listOf types.path;
      default = [
        "${pkgs.gentle-ai-assets}/share/gentle-ai/AGENTS.md"
        ./rules/explore-mcp.md
        ./rules/output-format.md
      ];
      description = "Ordered AGENTS.md/CLAUDE.md fragments to concatenate.";
    };

    engramConfig = mkOption {
      type = types.attrsOf types.anything;
      default = { };
      description = "Engram configuration shared across Gentle AI tools.";
    };
  };
}
