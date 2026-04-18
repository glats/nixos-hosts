{ ... }:

{
  imports = [
    ./cachix.nix
    ./home-manager.nix
    ./logind.nix
    ./nix.nix
    ./packages.nix
    ./polkit.nix
    ./sops.nix
    ./users.nix
    ./zsh.nix
  ];
}
