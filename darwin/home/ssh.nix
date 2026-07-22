{ config, primaryUser, ... }:
let
  sshDir = "${config.home.homeDirectory}/.ssh";
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
      # LAN hosts (legacy hosts kept for convenience)
      "asus-rog.local" = {
        SetEnv = {
          TERM = "xterm-256color";
        };
      };

      "172.16.0.198" = {
        SetEnv = {
          TERM = "xterm-256color";
        };
      };

      "rog.local" = {
        HostName = "rog.local";
        User = "glats";
        IdentityFile = "${sshDir}/glats-rog";
        SetEnv = {
          TERM = "xterm-256color";
        };
      };

      "t14.local" = {
        HostName = "t14.local";
        User = "glats";
        IdentityFile = "${sshDir}/t14";
        SetEnv = {
          TERM = "xterm-256color";
        };
      };

      "CLFTCC02G54THMD6N.local" = {
        HostName = "CLFTCC02G54THMD6N.local";
        User = primaryUser;
        IdentityFile = "${sshDir}/mac";
        SetEnv = {
          TERM = "xterm-256color";
        };
      };

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
    };
  };
}
