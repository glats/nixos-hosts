{ ... }:

{
  home.opencode = {
    enable = true;
    runtime = "stable";
    legacyFallback = false;

    agentOverrides.sdd-orchestrator.model = "deepinfra/moonshotai/Kimi-K2.5";

    plugins = {
      backgroundAgents.enable = true;
      engram.enable = true;
    };
  };
}
