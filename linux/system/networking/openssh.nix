{ pkgs, lib, ... }:

{
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = true;
      PermitRootLogin = "no";
      PubkeyAuthentication = true;
    };
  };

  # Replace the ugly x11-ssh-askpass GTK window with rofi.
  # When SSH needs a password and has no TTY (e.g. inside tmux from
  # OpenCode), it uses SSH_ASKPASS.  This wrapper picks up XAUTHORITY
  # (required for XRDP sessions) and uses the base16-themed rofi dialog.
  programs.ssh.askPassword = lib.mkForce (
    let
      rofiAskpass = pkgs.writeShellApplication {
        name = "rofi-ssh-askpass";
        runtimeInputs = [ pkgs.rofi ];
        text = ''
          export XAUTHORITY="''${XAUTHORITY:-$HOME/.Xauthority}"
          exec rofi -dmenu -password -p "''${1:-SSH}" -theme ulauncher-like -no-history
        '';
      };
    in
    "${rofiAskpass}/bin/rofi-ssh-askpass"
  );
}
