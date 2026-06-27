{
  config,
  lib,
  pkgs,
  ...
}:

{
  environment.systemPackages = with pkgs; [ cachix ];

  # The mkBefore / mkAfter distinction matters for darwin too: future
  # darwin modules may add their own substituters / trusted-public-keys,
  # and we want the fastly mirrors to stay at the top of the lookup
  # order while the rest of the cachix list stays at the bottom. We
  # use lib.mkMerge to declare two attrset slices that the NixOS
  # option system combines with the right merge semantics — a single
  # `nix.settings = { ... }` literal cannot have two `substituters`
  # keys (Nix rejects duplicate attribute names).
  nix.settings = lib.mkMerge [
    {
      # Fastly mirrors — same S3-backed nixos cache, different CDN
      # edges. Mirrors `modules/base/nix.nix` (mkBefore) on linux so
      # mact2 benefits from the same lower-latency fetch path.
      substituters = lib.mkBefore [
        "https://aseipp-nix-cache.freetls.fastly.net"
        "https://aseipp-nix-cache.global.ssl.fastly.net"
      ];
    }
    {
      # Full cachix list — mirrors `modules/base/cachix.nix` on
      # linux. The 3 entries beyond cache.nixos.org / nix-community
      # / ghostty are the ones the linux config already pulls
      # (nixpkgs-unfree, flox, nixpkgs). Darwin needs the same
      # coverage to avoid unnecessary source builds on mact2.
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
    }
  ];
}
