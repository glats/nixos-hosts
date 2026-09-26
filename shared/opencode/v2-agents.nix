{ lib, cfg }:

let
  mode = value:
    if value == "subagent" then "subagent" else if value == "primary" then "primary" else "all";
  remap = _: agent:
    (lib.removeAttrs agent [ "prompt" "disable" "maxSteps" "mode" "tools" "permission" ])
    // lib.optionalAttrs (agent ? prompt) { system = agent.prompt; }
    // lib.optionalAttrs (agent ? disable) { disabled = agent.disable; }
    // lib.optionalAttrs (agent ? maxSteps) { steps = agent.maxSteps; }
    // { mode = mode (agent.mode or "all"); };
in
lib.mapAttrs remap cfg.agents
