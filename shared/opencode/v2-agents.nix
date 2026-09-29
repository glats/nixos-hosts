{
  lib,
  cfg,
  permissionRules,
}:

let
  mode =
    value:
    if value == "subagent" then
      "subagent"
    else if value == "primary" then
      "primary"
    else
      "all";
  remap =
    _: agent:
    (lib.removeAttrs agent [
      "maxSteps"
      "tools"
      "prompt"
      "disable"
      "permission"
      "mode"
    ])
    // lib.optionalAttrs (agent ? maxSteps) { steps = agent.maxSteps; }
    // lib.optionalAttrs (agent ? prompt) { system = agent.prompt; }
    // lib.optionalAttrs (agent ? disable) { disabled = agent.disable; }
    // lib.optionalAttrs (agent ? permission) { permissions = permissionRules agent.permission; }
    // {
      mode = mode (agent.mode or "all");
    };
in
lib.mapAttrs remap cfg.agents
