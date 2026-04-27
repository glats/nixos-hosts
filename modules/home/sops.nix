{ config, ... }:

{
  # Home-manager sops config - uses user key for user-specific secrets
  sops.defaultSopsFile = ../../secrets/user/api_keys.yaml;
  sops.age.keyFile = "${config.home.homeDirectory}/.config/sops/age/keys.txt";

  # OpenCode API keys (just declare the secrets, no special options needed for HM)
  # Note: opencode_go_api_key is NOT declared here - OpenCode Go uses /connect command for OAuth authentication
  sops.secrets."opencode/fireworks_api_key" = { };
  sops.secrets."opencode/deepinfra_api_key" = { };
  sops.secrets."opencode/anthropic_api_key" = { };
  sops.secrets."opencode/openai_api_key" = { };
  sops.secrets."opencode/siliconflow_api_key" = { };
}
