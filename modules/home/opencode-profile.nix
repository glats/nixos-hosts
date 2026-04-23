{ ... }:

{
  home.opencode = {
    enable = true;
    runtime = "stable";
    legacyFallback = false;

    agentOverrides.sdd-orchestrator.model = "openai/gpt-5.4";

    plugins = {
      backgroundAgents.enable = true;
      engram.enable = true;
    };
  };
}
