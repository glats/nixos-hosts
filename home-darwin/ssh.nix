{ pkgs, primaryUser, ... }:
{
  # Manage ~/.ssh/config so SSH uses the github key we generated
  home.file.".ssh/config".text = ''
    # Restored entries from previous ~/.ssh/config
    Include /Users/${primaryUser}/.colima/ssh_config

    Host asus-rog.local
      SetEnv TERM=xterm-256color

    Host 172.16.0.198
      SetEnv TERM=xterm-256color

    Host rog.local
      HostName 172.16.0.5
      User glats
      IdentityFile /Users/${primaryUser}/.ssh/glats-rog

    Host CLFTCC02G54THMD6N.local
      HostName CLFTCC02G54THMD6N.local
      User ${primaryUser}
      IdentityFile /Users/${primaryUser}/.ssh/mac
      SetEnv TERM=xterm-256color

    # GitHub keys managed by Home Manager
    Host github.com
      HostName github.com
      User git
      IdentityFile ~/.ssh/id_ed25519_github
      AddKeysToAgent yes
      UseKeychain yes
      IdentitiesOnly yes

    # Personal GitHub key (used for personal account). Use an alias so we
    # can keep enterprise and personal keys separate even though both use
    # github.com as HostName.
    Host github-personal
      HostName github.com
      User git
      IdentityFile ~/.ssh/id_ed25519_personal
      AddKeysToAgent yes
      UseKeychain yes
      IdentitiesOnly yes

    # Enterprise GitHub host alias — keeps enterprise key separate from personal
    Host github-enterprise
      HostName github.com
      User git
      IdentityFile ~/.ssh/id_ed25519_github
      AddKeysToAgent yes
      UseKeychain yes
      IdentitiesOnly yes
  '';

  # Default permissions are acceptable; ensure SSH keys have correct perms separately
}
