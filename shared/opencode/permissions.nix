{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  defaultPermissions = {
    external_directory = {
      "/**" = "allow";
    };
    bash = {
      "*" = "allow";
      "sops*" = "deny";
      "git commit *" = "ask";
      "git push" = "ask";
      "git push *" = "ask";
      "git push --force *" = "ask";
      "git rebase *" = "ask";
      "git reset --hard *" = "ask";
    };
    read = {
      "*" = "allow";
      "**/.env" = "deny";
      "**/.env.*" = "deny";
      "*.env" = "deny";
      "*.env.*" = "deny";
      "/run/secrets/**" = "deny";
      "**/secrets/**" = "deny";
      "**/credentials.json" = "deny";
    };
  };
in
{
  options.home.opencode.permissions = mkOption {
    type = types.attrs;
    default = defaultPermissions;
    description = ''
      Permission rules for OpenCode agents.

      Keys:
      - external_directory: Rules for external directory access
      - bash: Rules for bash command execution
      - read: Rules for file read access

      Values are attrsets where:
      - Keys are glob patterns (e.g., "*", "**/.env", "git push *")
      - Values are permission levels: "allow", "deny", or "ask"

      Example:
      {
        bash = {
          "rm -rf /" = "deny";
          "git *" = "allow";
        };
      }
    '';
  };
}
