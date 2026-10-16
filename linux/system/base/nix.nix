{
  lib,
  inputs,
  pkgs,
  ...
}:

{
  nix.gc = {
    automatic = false;
    dates = "weekly";
    randomizedDelaySec = "1h";
  };

  nix.settings = (import ../../../shared/nix-resilience.nix) // {
    experimental-features = [
      "nix-command"
      "flakes"
    ];
    auto-optimise-store = true;

    max-jobs = lib.mkDefault 1;

    cores = 0;

    keep-outputs = true;

    substituters = lib.mkBefore [
      "https://aseipp-nix-cache.freetls.fastly.net"
      "https://aseipp-nix-cache.global.ssl.fastly.net"
    ];

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

  nix.registry.nixpkgs.flake = inputs.nixpkgs;

  system.extraDependencies =
    let
      collectFlakeInputs =
        input:
        [ input.outPath ]
        ++ builtins.concatMap collectFlakeInputs (builtins.attrValues (input.inputs or { }));

      derivedSrcs =
        let
          srcsOf = flake: map (p: p.src or null) (builtins.attrValues (flake.packages.${pkgs.system} or { }));
          candidates =
            srcsOf inputs.omarchy-nix.inputs.hyprland
            ++ srcsOf inputs.omarchy-nix.inputs.walker
            ++ srcsOf inputs.omarchy-nix.inputs.elephant
            ++ srcsOf (inputs.omarchy-nix.inputs.walker.inputs.elephant or { })
            ++ srcsOf (inputs.omarchy-nix.inputs.hyprland.inputs.xdph or { });
          tried = builtins.tryEval (builtins.filter (s: s != null) candidates);
        in
        if tried.success then tried.value else [ ];
    in
    builtins.concatMap collectFlakeInputs (builtins.attrValues inputs) ++ derivedSrcs;
}
