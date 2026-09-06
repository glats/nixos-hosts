{ lib, ... }:

{
  imports = [
    ./ai-assets.nix
  ];

  # Gentle AI shared ecosystem enabled when any tool uses it
  home.ai-assets.enable = true;

  home.opencode = {
    enable = true;

    # Default provider tier; override per-host in the host's default.nix.
    # mkDefault so per-host plain assignments win without mkForce.
    activeProviderName = lib.mkDefault "opencode-go-full";

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

    # v2.5.0 managed plugins: sdd-task-result-artifacts and skill-registry
    # enabled; model-variants and opencode-review-transport stay off (opt-in).
    plugins = {
      sddTaskResultArtifacts.enable = true;
      skillRegistry.enable = true;
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
