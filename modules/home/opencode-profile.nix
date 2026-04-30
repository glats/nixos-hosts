{ ... }:

{
  home.opencode = {
    enable = true;

    # Enable background agents plugin (has known orchestration issues - see issue #58)
    plugins = {
      backgroundAgents.enable = true;
      engram.enable = true;
    };

    # TUI plugins
    tuiPlugins = {
      subAgentStatusline.enable = true;
      sddEngramManage.enable = true;
    };
  };
}
