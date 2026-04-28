{ ... }:

{
  home.opencode = {
    enable = true;
    runtime = "stable";

    # Default model for neutral agent (built-in OpenCode Go)
    agentOverrides.neutral.model = "opencode-go/kimi-k2.5";

    plugins = {
      backgroundAgents.enable = true;
      engram.enable = true;
    };

    tuiPlugins = {
      subAgentStatusline.enable = true;
      sddEngramManage.enable = true;
    };
  };
}
