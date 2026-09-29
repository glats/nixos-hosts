{
  lib,
  mcps,
  browserMcp,
}:

{
  servers =
    (lib.mapAttrs (
      _: mcp:
      lib.removeAttrs mcp [
        "enabled"
        "type"
      ]
      // lib.optionalAttrs ((mcp.type or "local") == "remote") { type = "remote"; }
      // lib.optionalAttrs ((mcp.type or "local") == "local") { type = "local"; }
      // {
        disabled = !(mcp.enabled or false);
      }
    ) mcps)
    // lib.optionalAttrs browserMcp.enable {
      browsermcp = {
        type = "remote";
        url = "http://127.0.0.1:${toString browserMcp.bridgePort}/mcp";
      };
    };
}
