{
  lib,
  cfg,
  disabledTools,
}:

let
  action =
    name:
    {
      bash = "shell";
      task = "subagent";
      write = "edit";
      patch = "edit";
    }
    .${name} or name;
  rules =
    permissions:
    lib.concatMap (
      name:
      let
        value = permissions.${name};
      in
      if builtins.isAttrs value then
        lib.mapAttrsToList (resource: effect: {
          action = action name;
          inherit resource effect;
        }) value
      else
        [
          {
            action = action name;
            resource = "*";
            effect = value;
          }
        ]
    ) (lib.attrNames permissions);
  mcpDenies = map (resource: {
    action = builtins.replaceStrings [ "-" ] [ "_" ] resource;
    resource = "*";
    effect = "deny";
  }) disabledTools;
in
{
  inherit rules;
  global = mcpDenies ++ rules cfg.permissions;
}
