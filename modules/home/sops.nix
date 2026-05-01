{ config, ... }:

{
  # Home-manager sops config - uses user key for user-specific secrets
  sops.defaultSopsFile = ../../secrets/user/api_keys.yaml;
  sops.age.keyFile = "${config.home.homeDirectory}/.config/sops/age/keys.txt";

  # NVIDIA NIM API key for OpenCode provider
  sops.secrets."opencode/nvidia_api_key" = {
    mode = "0400";
  };

  # Groq API key for OpenCode provider
  sops.secrets."opencode/groq_api_key" = {
    mode = "0400";
  };

  # Cerebras API key for OpenCode provider
  sops.secrets."opencode/cerebras_api_key" = {
    mode = "0400";
  };

  # TODO: OpenCode Zen API key - add when available
  # sops.secrets."opencode/opencode_api_key" = {
  #   mode = "0400";
  # };
}
