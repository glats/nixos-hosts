# MCPs configuration for shared opencode
# Imports base MCPs (github, nixos, context7, engram, exa)
{ lib, ... }:

{
  imports = [
    ./mcps-base.nix
  ];

  # Extra MCPs merged with base MCPs at config generation time.
  # Platform-specific modules (e.g., home-darwin/opencode/mcps-extra.nix)
  # can inject additional MCPs here without overriding the base set.
  options.home.gentle-ai.extraMcps = lib.mkOption {
    type = lib.types.attrsOf (lib.types.submodule { freeformType = lib.types.attrs; });
    default = { };
    description = "Extra MCP servers merged with home.gentle-ai.mcps.";
  };
}
