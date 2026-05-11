{ ... }:

{
  home.opencode = {
    enable = true;

    # backgroundAgents: disabled due to known orchestration issues (gentle-ai#58)
    # Keep option definition in plugins.nix but do not enable here
    plugins = {
      # backgroundAgents.enable = true; # DISABLED - see issue #58
      engram.enable = true;
      secretGuard.enable = true; # Runtime redaction of secrets from bash output
    };

    # TUI plugins
    tuiPlugins = {
      subAgentStatusline.enable = true;
      sddEngramManage.enable = true;
    };
  };
}
