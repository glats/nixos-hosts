{ lib, ... }:

{
  imports = [
    ./gentle-ai-common.nix
  ];

  # Gentle AI shared ecosystem enabled when any tool uses it
  home.gentle-ai.enable = true;

  home.opencode = {
    enable = true;

    # Default provider tier; override per-host in the host's default.nix.
    # mkDefault so per-host plain assignments win without mkForce.
    activeProviderName = lib.mkDefault "opencode-go-medium";

    # Built-in providers we don't use
    disabledProviders = [
      "cerebras"
      "cloudflare-ai-gateway"
      "cloudflare-workers-ai"
      "cohere"
      "groq"
      "kilo"
      "mistral"
      "openrouter"
      "google"
    ];

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
      sddEngramManage.enable = false;
    };
  };
}
