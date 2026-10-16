{ inputs, ... }:

{
  nix = {
    enable = false;

    registry.nixpkgs.flake = inputs.nixpkgs;
  };

  determinateNix.customSettings = (import ../../shared/nix-resilience.nix) // {
    keep-outputs = true;

    max-jobs = 1;
  };

  nixpkgs.config.allowUnfree = true;
}
