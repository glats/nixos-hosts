{ lib, cfg, disabledTools }:

let
  action = name: if name == "bash" then "shell" else if name == "task" then "subagent" else name;
  rules = lib.concatMap (name:
    lib.mapAttrsToList (resource: effect: {
      action = action name;
      inherit resource effect;
    }) cfg.permissions.${name}
  ) (lib.attrNames cfg.permissions);
  mcpDenies = map (resource: {
    action = "mcp";
    inherit resource;
    effect = "deny";
  }) disabledTools;
in
mcpDenies ++ rules
