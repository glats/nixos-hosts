{ config
, lib
, pkgs
, inputs
, ...
}:

{
  environment.systemPackages = with pkgs; [ cachix ];

  # The mkBefore / mkAfter distinction matters for darwin too: future
  # darwin modules may add their own substituters / trusted-public-keys,
  # and we want the fastly mirrors to stay at the top of the lookup
  # order while the rest of the cachix list stays at the bottom. We
  # use lib.mkMerge to declare multiple attrset slices that the NixOS
  # option system combines with the right merge semantics — a single
  # `nix.settings = { ... }` literal cannot have two `substituters`
  # keys (Nix rejects duplicate attribute names).
  #
  # This file also holds the nix build-optimization options
  # (max-jobs, cores, keep-outputs, trusted-substituters, registry)
  # to keep all `nix.settings` / `nix.registry` declarations in one
  # place. Mirrors `modules/base/nix.nix` on linux.
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
    {
      # Build optimization options — mirrors `modules/base/nix.nix`
      # on linux. See that file for full rationale.

      # Build parallelism: limit max concurrent jobs to prevent OOM
      # and laptop freezes. `auto` (default) spawns one job per
      # logical core which can blow past available memory when
      # several rustc/ghc/etc instances run simultaneously. mkDefault
      # lets a host bump this without needing mkForce.
      max-jobs = lib.mkDefault 1;

      # All available cores per derivation (-j for make). 0 == all
      # cores. Exposed explicitly for clarity even though it matches
      # the default.
      cores = 0;

      # Retain build outputs across `nix-collect-garbage`. Without
      # this, a package that gets garbage-collected from the store
      # is fully recompiled on the next build, even if its sources
      # haven't changed. Trades ~30% more /nix/store disk for
      # dramatically faster rebuilds.
      keep-outputs = true;

      # Trusted substituters: mirror of the full substituter list
      # so non-root users (e.g. when running `nix shell nixpkgs#foo`
      # unprivileged) can pull from the same binary caches root
      # can. Without this, non-root users are restricted to
      # cache.nixos.org plus any caches they specify explicitly
      # with --option binary-caches.
      trusted-substituters = [
        "https://aseipp-nix-cache.freetls.fastly.net"
        "https://aseipp-nix-cache.global.ssl.fastly.net"
        "https://cache.nixos.org/"
        "https://nix-community.cachix.org"
        "https://ghostty.cachix.org"
        "https://nixpkgs-unfree.cachix.org"
        "https://cache.flox.dev"
        "https://nixpkgs.cachix.org"
      ];
    }
  ];

  # Pin the system-wide flake registry so that bare references like
  # `nixpkgs#hello` or `nixpkgs#pkg` resolve to the flake-locked
  # nixpkgs used to build the system, rather than fetching whatever
  # nixos-unstable points at today. This avoids unnecessary network
  # tree fetches and produces reproducible package builds even when
  # the user does not pass `--flake` explicitly. Mirrors
  # `modules/base/nix.nix` on linux.
  nix.registry.nixpkgs.flake = inputs.nixpkgs;
}
