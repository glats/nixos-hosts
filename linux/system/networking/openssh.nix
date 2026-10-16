{ pkgs, lib, ... }:

let
  mesh = import ../../../shared/ssh/lan-mesh.nix { inherit lib; };
in

{
  programs.ssh.knownHosts = mesh.knownHosts;

  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = true;
      PermitRootLogin = "no";
      PubkeyAuthentication = true;
    };
  };

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
