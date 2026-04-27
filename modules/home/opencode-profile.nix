{ ... }:

{
  home.opencode = {
    enable = true;
    runtime = "stable";
    legacyFallback = false;

    plugins = {
      backgroundAgents.enable = true;
      engram.enable = true;
    };
  };
}
