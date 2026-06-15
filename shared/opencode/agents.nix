{ config
, lib
, pkgs
, ...
}:

with lib;

let
  # Import centralized provider configuration
  providersConfig = import ./providers.nix { inherit lib; };

  # Read upstream agent definitions from vanilla assets
  upstreamOverlay = builtins.fromJSON (
    builtins.readFile "${pkgs.gentle-ai-assets-vanilla}/share/gentle-ai/opencode/sdd-overlay-single.json"
  );
  upstreamAgents = upstreamOverlay.agent or { };

  # SDD phase names (for model assignment lookup)
  sddPhases = [
    "sdd-init"
    "sdd-explore"
    "sdd-propose"
    "sdd-spec"
    "sdd-design"
    "sdd-tasks"
    "sdd-apply"
    "sdd-verify"
    "sdd-archive"
    "sdd-onboard"
  ];

  # Build agent models from active provider
  agentModels =
    let
      active = providersConfig.activeProvider;
    in
    if active != null then
      builtins.mapAttrs (phase: _: providersConfig.getModelForPhase phase active)
        (
          builtins.listToAttrs (
            map
              (p: {
                name = p;
                value = null;
              })
              sddPhases
          )
        )
    else
      { };

  # Final model assignments for all agents
  models =
    if providersConfig.activeProvider != null then
      agentModels
      // {
        neutral = providersConfig.getModelForPhase "neutral" providersConfig.activeProvider;
        gentle-orchestrator = providersConfig.getModelForPhase "gentle-orchestrator" providersConfig.activeProvider;
      }
    else
      throw "No active provider found. Check activeProviderName in shared/opencode/providers-base.nix";

  # Local tools to overlay on all agents (mem tools for engram integration)
  localOrchestratorTools = {
    mem_search = true;
    mem_save = true;
    mem_get_observation = true;
    delegation_list = true;
    delegation_read = true;
  };

  localSubAgentTools = {
    mem_search = true;
    mem_save = true;
    mem_get_observation = true;
  };

  # Smart merge: respect upstream __replace__ markers
  # __replace__ means the upstream value is a complete unit;
  # local values are merged on top of that unit.
  smartMerge =
    local: upstream:
    if upstream ? "__replace__" then
      lib.recursiveUpdate upstream.__replace__ local
    else
      lib.recursiveUpdate upstream local;

  # Recursively strip __replace__ markers from a nested attrset
  # so they don't leak into the final JSON.
  stripReplace =
    val: if isAttrs val then mapAttrs (_: stripReplace) (removeAttrs val [ "__replace__" ]) else val;

  # Overlay an upstream agent with local fields
  overlayAgent =
    name: upstream:
    let
      localModel = models.${name} or null;
      localTools =
        if name == "gentle-orchestrator" then
          localOrchestratorTools
        else if upstream.mode or "" == "subagent" then
          localSubAgentTools
        else
          { };
      localPermission =
        if name == "gentle-orchestrator" then
          {
            task = {
              "*" = "deny";
              "sdd-*" = "allow";
            };
          }
        else
          { };
    in
    stripReplace (
      (removeAttrs upstream [ ])
      // lib.optionalAttrs (localModel != null) { model = localModel; }
      // lib.optionalAttrs (localTools != { }) {
        tools = smartMerge localTools (upstream.tools or { });
      }
      // lib.optionalAttrs (localPermission != { }) {
        permission = smartMerge localPermission (upstream.permission or { });
      }
    );

  # Neutral agent (local-only, not in upstream JSON)
  neutralAgent = {
    description = "Senior Architect mentor - helpful first, challenging when it matters";
    mode = "primary";
    prompt = "{file:./IDENTITY.md}\n\n{file:./SYSTEM_RULES.md}";
    tools = {
      bash = true;
      read = true;
      edit = true;
      write = true;
      delegate = true;
      task = true;
      delegation_list = true;
      delegation_read = true;
      mem_search = true;
      mem_save = true;
      mem_get_observation = true;
    };
    model = models.neutral;
  };

  # Final agent set: upstream + model overlay + tools overlay + neutral
  defaultAgents = (lib.mapAttrs overlayAgent upstreamAgents) // {
    neutral = neutralAgent;
  };
in
{
  options.home.opencode.agentOverrides = mkOption {
    type = types.attrsOf (
      types.submodule {
        freeformType = types.attrs;
      }
    );
    default = { };
    description = ''
      Per-agent overrides merged on top of the default OpenCode agent set.
      Use this for runtime-specific model or prompt changes without replacing
      the entire default agent graph.
    '';
  };

  options.home.opencode.agents = mkOption {
    type = types.attrsOf (
      types.submodule {
        freeformType = types.attrs;
      }
    );
    default = { };
    description = ''
      Computed OpenCode agent graph after merging upstream defaults with
      `home.opencode.agentOverrides`.
    '';
  };

  config.home.opencode.agents = lib.recursiveUpdate defaultAgents config.home.opencode.agentOverrides;
}
