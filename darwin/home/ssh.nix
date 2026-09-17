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

    # Colima-provided hosts are managed by Colima at runtime; include
    # its config so SSH resolves them without us redeclaring the hosts.
    includes = [
      "${config.home.homeDirectory}/.colima/ssh_config"
    ];

    settings = {
      # GitHub keys managed by Home Manager
      "github.com" = {
        HostName = "github.com";
        User = "git";
        IdentityFile = "~/.ssh/id_ed25519_github";
        # UseKeychain and AddKeysToAgent are macOS-specific options
        # not typed by Home Manager; they pass through the freeform
        # `settings.<name>` attrs and end up in ~/.ssh/config verbatim.
        AddKeysToAgent = "yes";
        UseKeychain = "yes";
        IdentitiesOnly = "yes";
      };

      # Personal GitHub key. Use an alias so enterprise and personal
      # keys stay separate even though both resolve to github.com.
      "github-personal" = {
        HostName = "github.com";
        User = "git";
        IdentityFile = "~/.ssh/id_ed25519_personal";
        AddKeysToAgent = "yes";
        UseKeychain = "yes";
        IdentitiesOnly = "yes";
      };

      # Enterprise GitHub host alias — keeps enterprise key separate
      # from the personal one.
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
