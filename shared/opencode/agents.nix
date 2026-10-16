{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  providersConfig = import ./providers.nix {
    inherit lib;
    activeProviderName = config.home.opencode.activeProviderName;
  };

  upstreamOverlay = builtins.fromJSON (
    builtins.readFile "${pkgs.gentle-ai-assets}/share/gentle-ai/opencode/odd-overlay.json"
  );
  upstreamAgents = upstreamOverlay.agent or { };

  routedAgents = [
    "gentle-ai-explore"
    "gentle-ai-worker"
    "gentle-ai-verify"
    "jd-judge-a"
    "jd-judge-b"
    "jd-fix-agent"
    "review-readability"
    "review-refuter"
    "review-reliability"
    "review-resilience"
    "review-risk"
    "review-validator"
  ];

  agentModels =
    let
      active = providersConfig.activeProvider;
    in
    if active != null then
      builtins.mapAttrs (role: _: providersConfig.getModelForRole role active) (
        builtins.listToAttrs (
          map (p: {
            name = p;
            value = null;
          }) routedAgents
        )
      )
    else
      { };

  models =
    if providersConfig.activeProvider != null then
      agentModels
      // {
        neutral = providersConfig.getModelForRole "neutral" providersConfig.activeProvider;
        gentle-orchestrator = providersConfig.getModelForRole "gentle-orchestrator" providersConfig.activeProvider;
      }
    else
      throw "No active provider found. Check activeProviderName in shared/opencode/providers-base.nix";

  localOverlays = builtins.fromJSON (builtins.readFile ./local-agent-overlays.json);

  smartMerge =
    local: upstream:
    if upstream ? "__replace__" then
      lib.recursiveUpdate upstream.__replace__ local
    else
      lib.recursiveUpdate upstream local;

  stripReplace =
    val: if isAttrs val then mapAttrs (_: stripReplace) (removeAttrs val [ "__replace__" ]) else val;

  overlayAgent =
    name: upstream:
    let
      localModel = models.${name} or null;
      namedOverlay = localOverlays.permissionOverlays.named.${name} or { };
      localInstructions =
        if builtins.hasAttr name localOverlays.instructionOverlays then
          localOverlays.instructionOverlays.${name}
        else if upstream.mode or "" == "subagent" then
          localOverlays.instructionOverlays.subagent or [ ]
        else
          [ ];
    in
    stripReplace (
      let
        instructionPrompt =
          if localInstructions != [ ] then
            (lib.concatStringsSep "\n\n" (map (f: builtins.readFile ./${f}) localInstructions)) + "\n\n"
          else
            "";
        basePrompt = upstream.prompt or "";
      in
      (removeAttrs upstream [ "tools" ])
      // lib.optionalAttrs (localModel != null) { model = localModel; }
      // lib.optionalAttrs (instructionPrompt != "" || basePrompt != "") {
        prompt = instructionPrompt + basePrompt;
      }
      // {
        permission = smartMerge namedOverlay (upstream.permission or { });
      }
    );

  neutralAgent = localOverlays.neutral // {
    model = models.neutral;
    prompt =
      builtins.readFile "${pkgs.gentle-ai-assets}/share/gentle-ai/opencode/persona-gentleman.md"
      + "\n\n"
      + builtins.readFile ../rules/code-comments.md;
  };

  managedWritingAgent = {
    description = "Edit and test only the assigned managed worktree; never integrate or mutate a host.";
    mode = "primary";
    prompt = ''
      You are the managed-writing-task agent. Work only in the assigned worktree.
      You may edit files, inspect branch-local Git state, commit local work, run tests,
      Never activate, update inputs, change profiles or generations, use sudo or
      services, push, integrate, clean up, or access external directories.

    ''
    + builtins.readFile ../rules/code-comments.md;
    permission = localOverlays.permissionOverlays.named.managed-writing-task;
  };

  defaultAgents = (lib.mapAttrs overlayAgent upstreamAgents) // {
    neutral = neutralAgent;
    managed-writing-task = managedWritingAgent;
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
