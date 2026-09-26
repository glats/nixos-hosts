{ lib, mcps }:

{
  servers = lib.mapAttrs (_: mcp:
    lib.removeAttrs mcp [ "enabled" "type" ]
    // lib.optionalAttrs ((mcp.type or "local") == "remote") { type = "remote"; }
    // lib.optionalAttrs ((mcp.type or "local") == "local") { type = "local"; }
    // { disabled = !(mcp.enabled or false); }
  ) mcps;
}
