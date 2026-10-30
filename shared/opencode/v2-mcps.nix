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
        type = "local";
        command = [ "${browserMcp.package}/bin/mcp-server-browsermcp" ];
        disabled = false;
      };
    };
}
