{ ... }:

{
  home.opencode = {
    enable = true;
    runtime = "stable";
    legacyFallback = false;

    agentOverrides.sdd-orchestrator.model = "opencode/nemotron-3-super-free";

    plugins = {
      backgroundAgents.enable = true;
      engram.enable = true;
    };
  };
}
