# Darwin nix configuration -- mirrors modules/base/nix.nix for NixOS.
# Consolidated from darwin/default.nix (experimental features, nix.enable,
# allowUnfree) and darwin/cachix.nix (build optimization, registry).
# All nix.* settings for Darwin hosts live in this single file.
{ lib, inputs, ... }:
{
  nix = {
    settings = {
      experimental-features = [
        "nix-command"
        "flakes"
      ];
      # disabled due to https://github.com/NixOS/nix/issues/7273
      # auto-optimise-store = true;

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

      # Trusted substituters: mirror of the full substituter list so
      # non-root users (e.g. when running `nix shell nixpkgs#foo`
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
    };
    enable = false; # using Determinate installer

    # Pin the system-wide flake registry so that bare references like
    # `nixpkgs#hello` or `nixpkgs#pkg` resolve to the flake-locked
    # nixpkgs used to build the system, rather than fetching whatever
    # nixos-unstable points at today. This avoids unnecessary network
    # tree fetches and produces reproducible package builds even when
    # the user does not pass `--flake` explicitly. Mirrors
    # `modules/base/nix.nix` on linux.
    registry.nixpkgs.flake = inputs.nixpkgs;
  };

  nixpkgs.config.allowUnfree = true;
}
