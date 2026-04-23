{ ... }:

{
  imports = [
    ./cachix.nix
    ./home-manager.nix
    ./logind.nix
    ./nix.nix
    ./packages.nix
    ./polkit.nix
    ./shutdown-fix.nix
    ./sops.nix
    ./users.nix
    ./zsh.nix
  ];
}
