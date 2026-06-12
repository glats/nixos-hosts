{ config
, lib
, pkgs
, ...
}:

{
  options.nix.cachix-custom = {
    enable = lib.mkEnableOption "Cachix binary cache configuration" // {
      default = true;
    };
  };

  config = lib.mkIf config.nix.cachix-custom.enable {
    environment.systemPackages = with pkgs; [ cachix ];

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
        "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZvDo1tvuGySTdw="
        "nix-community.cachix.org-1:7Nw0m1eeP3Gg3RhbC8Vy/Z4GqW2ZJYX9F8Nc8eeeCJ8="
        "ghostty.cachix.org-1:QB389yTa6gTyneehvqG58y0WnHjQOqgnA+wBnpWWxns="
        "nixpkgs-unfree.cachix.org-1:hqvoInulhbV4nJ9yJOEr+4wxhDV4xq2d1DK7S6Nj6rs="
        "flox-cache-public-1:7F4OyH7ZCnFhcze3fJdfyXYLQw/aV7GEed86nQ7IsOs="
        "nixpkgs.cachix.org-1:q91R6hxbwFvDqTSDKwDAV4T5PxqXGxswD8vhONFMeOE="
      ];
    };
  };
}
