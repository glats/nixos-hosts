{ lib, pkgs, ... }:

{
  home.ai-assets.extraMcps.supermercados = {
    type = "local";
    command = [ (lib.getExe pkgs.mcp-supermercados-cl) ];
    enabled = true;
  };
}
