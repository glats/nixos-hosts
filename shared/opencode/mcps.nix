{ lib, ... }:

{
  imports = [
    ./mcps-base.nix
  ];

  options.home.ai-assets.extraMcps = lib.mkOption {
    type = lib.types.attrsOf (lib.types.submodule { freeformType = lib.types.attrs; });
    default = { };
    description = "Extra MCP servers merged with home.ai-assets.mcps.";
  };
}
