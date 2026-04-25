{ ... }:

{
  home.opencode = {
    enable = true;
    runtime = "stable";
    legacyFallback = false;

    # Model override - uses Fireworks by default (change to deepinfra or remove to customize)
    agentOverrides.sdd-orchestrator.model = "fireworks/accounts/fireworks/models/kimi-k2p6";

    plugins = {
      backgroundAgents.enable = true;
      engram.enable = true;
    };
  };
}
