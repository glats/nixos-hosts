{ config, ... }:

{
  # Home-manager sops config - uses user key for user-specific secrets
  sops.defaultSopsFile = ../../secrets/user/api_keys.yaml;
  sops.age.keyFile = "${config.home.homeDirectory}/.config/sops/age/keys.txt";

  # OpenCode Go API key (for non-OAuth API access if needed)
  # Note: Primary authentication is via /connect command for OAuth
  sops.secrets."opencode/opencode_go_api_key" = { };
}
