{ config
, lib
, pkgs
, ...
}:

{
  environment.systemPackages = with pkgs; [ cachix ];

  nix.settings = {
    substituters = lib.mkAfter [
      "https://cache.nixos.org/"
      "https://nix-community.cachix.org"
      "https://ghostty.cachix.org"
    ];
    trusted-public-keys = lib.mkAfter [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZvDo1tvuGySTdw="
      "nix-community.cachix.org-1:7Nw0m1eeP3Gg3RhbC8Vy/Z4GqW2ZJYX9F8Nc8eeeCJ8="
      "ghostty.cachix.org-1:QB389yTa6gTyneehvqG58y0WnHjQOqgnA+wBnpWWxns="
    ];
  };
}
