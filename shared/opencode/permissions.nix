{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  # Static default permissions - no config references
  defaultPermissions = {
    external_directory = {
      "/**" = "allow";
    };
    bash = {
      "*" = "allow";
      # Block sops command execution to prevent accidental secret decryption
      "sops*" = "deny";
      "git commit *" = "ask";
      "git push" = "ask";
      "git push *" = "ask";
      "git push --force *" = "ask";
      "git rebase *" = "ask";
      "git reset --hard *" = "ask";
      # Managed writing agents must never reach host or shared-generation
      # mutation, even if a prompt attempts to disguise the command.
      "nixos-build *" = "deny";
      "nixos-rebuild *" = "deny";
      "darwin-rebuild *" = "deny";
      "home-manager *" = "deny";
      "nix profile *" = "deny";
      "nix-env *" = "deny";
      "nix flake update*" = "deny";
      "nix-collect-garbage*" = "deny";
      "sudo *" = "deny";
      "systemctl *" = "deny";
      "launchctl *" = "deny";
    };
    read = {
      # Deny-list semantics: "*" must be first, then specific denies
      "*" = "allow";
      # Environment files
      "**/.env" = "deny";
      "**/.env.*" = "deny";
      "*.env" = "deny";
      "*.env.*" = "deny";
      # Decrypted secrets and credential files
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
