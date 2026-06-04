{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:

{
  imports = [
    inputs.sops-nix.homeManagerModules.sops
    ../shared/sops.nix
  ];

  # macOS-specific secrets (Atlassian, Confluence, GitHub)
  sops.secrets."opencode/atlassian_jira_url" = {
    mode = "0400";
  };
  sops.secrets."opencode/atlassian_username" = {
    mode = "0400";
  };
  sops.secrets."opencode/atlassian_api_token" = {
    mode = "0400";
  };
  sops.secrets."opencode/confluence_url" = {
    mode = "0400";
  };
  sops.secrets."opencode/confluence_pat" = {
    mode = "0400";
  };
  sops.secrets."github/token" = {
    mode = "0400";
  };
}
