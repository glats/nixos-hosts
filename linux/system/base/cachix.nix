{ pkgs, ... }:

{
  imports = [
    ../../../shared/cachix.nix
  ];

  # Cachés binarios de Walker (solo Linux).
  #
  # `nix flake check` compila el toplevel de todos los hosts, así que el
  # stack omarchy de t14 (walker + sus crates vendorizados) puede compilarse
  # desde rog o thinkcentre. El flake de walker fija su propio nixpkgs
  # (rev de enero 2026), anterior al fix de crates.io (NixOS/nixpkgs#524985):
  # los fetchurl de crates devuelven HTTP 403 al compilar localmente. Los
  # cachés upstream tienen esos paths exactos (verificado con
  # `nix path-info --store`), así que la sustitución evita el fetch roto.
  nix.settings = {
    extra-substituters = [
      "https://walker.cachix.org"
      "https://walker-git.cachix.org"
    ];
    extra-trusted-public-keys = [
      "walker.cachix.org-1:fG8q+uAaMqhsMxWjwvk0IMb4mFPFLqHjuvfwQxE4oJM="
      "walker-git.cachix.org-1:vmC0ocfPWh0S/vRAQGtChuiZBTAe4wiKDeyyXM0/7pM="
    ];
  };

  environment.systemPackages = with pkgs; [ cachix ];
}
