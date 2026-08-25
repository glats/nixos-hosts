{ config
, lib
, pkgs
, inputs
, ...
}:

{
  imports = [
    inputs.sops-nix.homeManagerModules.sops
    ../../shared/sops.nix
  ];

  # macOS-specific secrets (Atlassian, Confluence)
  sops.secrets."opencode/atlassian_jira_url" = {
    sopsFile = ../../secrets/user/atlassian.yaml;
    mode = "0400";
  };
  sops.secrets."opencode/atlassian_username" = {
    sopsFile = ../../secrets/user/atlassian.yaml;
    mode = "0400";
  };
  sops.secrets."opencode/atlassian_api_token" = {
    sopsFile = ../../secrets/user/atlassian.yaml;
    mode = "0400";
  };
  sops.secrets."opencode/confluence_url" = {
    sopsFile = ../../secrets/user/atlassian.yaml;
    mode = "0400";
  };
  sops.secrets."opencode/confluence_pat" = {
    sopsFile = ../../secrets/user/atlassian.yaml;
    mode = "0400";
  };
  # The scoped client key for rog's OpenAI proxy is encrypted for mact2.
  # Keep it macOS-local so Linux hosts never attempt to decrypt a rog secret.
  sops.secrets."openai_proxy/client_key" = {
    sopsFile = ../../secrets/host/rog/openai-proxy.yaml;
    mode = "0400";
  };
  # GitHub tokens are now managed by `gh auth token` on darwin.
  # Linux hosts migrated to the same pattern (change: unify-github-auth).
}
