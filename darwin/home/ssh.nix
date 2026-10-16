{
  config,
  host ? null,
  hostName ? null,
  lib,
  ...
}:
let
  sshDir = "${config.home.homeDirectory}/.ssh";
  meshHost = if host != null then host else hostName;
  mesh = import ../../shared/ssh/lan-mesh.nix { inherit lib; };
in
{
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;

    includes = [
      "${config.home.homeDirectory}/.colima/ssh_config"
    ];

    settings = {
      "*".SetEnv.TERM = "xterm-256color";

      "github.com" = {
        HostName = "github.com";
        User = "git";
        IdentityFile = "~/.ssh/id_ed25519_github";
        AddKeysToAgent = "yes";
        UseKeychain = "yes";
        IdentitiesOnly = "yes";
      };

      "github-personal" = {
        HostName = "github.com";
        User = "git";
        IdentityFile = "~/.ssh/id_ed25519_personal";
        AddKeysToAgent = "yes";
        UseKeychain = "yes";
        IdentitiesOnly = "yes";
      };

      "github-enterprise" = {
        HostName = "github.com";
        User = "git";
        IdentityFile = "~/.ssh/id_ed25519_github";
        AddKeysToAgent = "yes";
        UseKeychain = "yes";
        IdentitiesOnly = "yes";
      };
    }
    // lib.optionalAttrs (meshHost == "macm5") (
      mesh.sshSettingsFor {
        source = "macm5";
        inherit sshDir;
      }
    );
  };
}
