{ ... }:

{
  home.opencode = {
    enable = true;
    runtime = "stable";
    legacyFallback = false;

    agentOverrides.sdd-orchestrator.model = "deepinfra/zai-org/GLM-5.1";

    plugins = {
      backgroundAgents.enable = true;
      engram.enable = true;
    };
  };
}
