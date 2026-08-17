# Darwin nix configuration -- mirrors modules/base/nix.nix for NixOS.
# Consolidated from darwin/default.nix (experimental features, nix.enable,
# allowUnfree) and darwin/cachix.nix (build optimization, registry).
# All nix.* settings for Darwin hosts live in this single file.
{ inputs, ... }:

{
  nix = {
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

  # Determinate Nix manages the daemon config itself (/etc/nix/nix.conf
  # with `!include nix.custom.conf`). nix-darwin's `nix.settings` is
  # SILENTLY IGNORED on this host, so daemon settings must go through
  # `determinateNix.customSettings` (the Determinate nix-darwin module
  # generates nix.custom.conf from this option only).
  determinateNix.customSettings = (import ../../shared/nix-resilience.nix) // {
    # Retain build outputs across `nix-collect-garbage`. Without this,
    # a package that gets garbage-collected from the store is fully
    # recompiled on the next build, even if its sources haven't
    # changed. Trades ~30% more /nix/store disk for dramatically
    # faster rebuilds.
    keep-outputs = true;

    # Limit concurrent jobs to prevent OOM and laptop freezes on this
    # Intel Mac (same intent as the linux max-jobs setting).
    max-jobs = 1;
  };

  nixpkgs.config.allowUnfree = true;
}
