{ lib, inputs, ... }:

{
  imports = [
    ../../../shared/nix-resilience.nix
  ];

  nix.gc = {
    automatic = false;
    dates = "weekly";
    randomizedDelaySec = "1h";
  };

  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];
    auto-optimise-store = true;

    # Build parallelism: limit max concurrent jobs to prevent OOM
    # and laptop freezes. `auto` (NixOS default) spawns one job per
    # logical core which can blow past available memory when several
    # rustc/ghc/rustc instances run simultaneously.
    # mkDefault lets a host bump this (e.g. rog's 16-core box) without
    # needing mkForce.
    max-jobs = lib.mkDefault 1;

    # All available cores per derivation (-j for make). 0 == all cores.
    # Exposed explicitly for clarity even though it matches the default.
    cores = 0;

    # Retain build outputs across `nix-collect-garbage`. Without this,
    # a package that gets garbage-collected from the store is fully
    # recompiled on the next build, even if its sources haven't changed.
    # Trades ~30% more /nix/store disk for dramatically faster rebuilds.
    # GC is manual (automatic=false above); clean up with
    # `nix-collect-garbage --delete-older-than 30d`.
    keep-outputs = true;

    # Cache alternativo: mirror Fastly que usa el mismo bucket S3 de cache.nixos.org
    # con binarios pre-firmados (sin necesidad de trusted-public-keys extra).
    # La URL freetls soporta IPv6 + HTTP/2.
    substituters = lib.mkBefore [
      "https://aseipp-nix-cache.freetls.fastly.net"
      "https://aseipp-nix-cache.global.ssl.fastly.net"
    ];

    # Trusted substituters: mirror of the full substituter list so
    # non-root users (e.g. when running `nix shell nixpkgs#foo`
    # unprivileged) can pull from the same binary caches root can.
    # Without this, non-root users are restricted to cache.nixos.org
    # plus any caches they specify explicitly with --option binary-caches.
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

  # Pin the system-wide flake registry so that bare references like
  # `nixpkgs#hello` or `nixpkgs#pkg` resolve to the flake-locked
  # nixpkgs used to build the system, rather than fetching whatever
  # nixos-unstable points at today. This avoids unnecessary network
  # tree fetches and produces reproducible package builds even when
  # the user does not pass `--flake` explicitly.
  nix.registry.nixpkgs.flake = inputs.nixpkgs;
}
