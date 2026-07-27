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
  # GitHub tokens — aligned with linux (same key, same file)
  sops.secrets."github/work_pat" = {
    sopsFile = ../../secrets/shared/passwords.yaml;
    mode = "0400";
  };
  sops.secrets."github/personal_pat" = {
    sopsFile = ../../secrets/shared/passwords.yaml;
    mode = "0400";
  };
}
