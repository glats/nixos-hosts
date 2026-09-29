{ lib, cfg }:

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
      "mode"
    ])
    // lib.optionalAttrs (agent ? maxSteps) { steps = agent.maxSteps; }
    // {
      mode = mode (agent.mode or "all");
    };
in
lib.mapAttrs remap cfg.agents
