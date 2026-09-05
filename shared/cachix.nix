{ lib, ... }:

{
  nix.settings = {
    substituters = lib.mkAfter [
      "https://cache.nixos.org/"
      "https://nix-community.cachix.org"
      "https://ghostty.cachix.org"
      "https://nixpkgs-unfree.cachix.org"
      "https://cache.flox.dev"
      "https://nixpkgs.cachix.org"
    ];

    trusted-public-keys = lib.mkAfter [
      # Key oficial de cache.nixos.org (misma que el default del módulo NixOS).
      # La anterior era incorrecta; en Linux la tapaba el default de NixOS,
      # pero en nix-darwin/Determinate no hay garantía de default.
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      # Key oficial de nix-community (https://nix-community.org/cache/).
      # La key anterior era incorrecta y hacía que Nix ignorara todos los
      # substitutos de este caché ("not signed by any of the keys").
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "ghostty.cachix.org-1:QB389yTa6gTyneehvqG58y0WnHjQOqgnA+wBnpWWxns="
      "nixpkgs-unfree.cachix.org-1:hqvoInulhbV4nJ9yJOEr+4wxhDV4xq2d1DK7S6Nj6rs="
      "flox-cache-public-1:7F4OyH7ZCnFhcze3fJdfyXYLQw/aV7GEed86nQ7IsOs="
      "nixpkgs.cachix.org-1:q91R6hxbwFvDqTSDKwDAV4T5PxqXGxswD8vhONFMeOE="
    ];
  };
}
