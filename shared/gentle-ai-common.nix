# Gentle AI common configuration shared across all tools (OpenCode, Claude Code, etc.)
# Defines MCPs, skills source, Engram config — consumed by tool-specific modules.
{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

{
  imports = [
    ./opencode/mcps-base.nix
    ./opencode/mcps.nix
  ];

  options.home.gentle-ai = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = "Enable Gentle AI ecosystem (shared MCPs, skills, Engram). Set by tool modules.";
    };

    skillsSource = mkOption {
      type = types.path;
      default = "${pkgs.gentle-ai-assets}/share/gentle-ai/skills";
      description = "Path to the skills directory from gentle-ai-assets derivation.";
    };

    engramConfig = mkOption {
      type = types.attrsOf types.anything;
      default = { };
      description = "Engram configuration shared across Gentle AI tools.";
    };
  };
}
