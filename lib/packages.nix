# Per-system package definitions extracted from flake.nix.
#
# Usage from flake.nix:
#   let
#     packages = import ./lib/packages.nix { inherit inputs; pkgsFor = pkgsFor; };
#   in
#   {
#     packages.x86_64-linux = packages.linuxPackages;
#     packages.x86_64-darwin = packages.darwinPackages;
#   }
{
  inputs,
  pkgsFor,
  ...
}:
let
  linuxPkgs = pkgsFor "x86_64-linux";
  darwinPkgs = pkgsFor "x86_64-darwin";

  # Packages built identically on both platforms.
  commonPackages =
    pkgs:
    let
      self = rec {
        nixos-scripts = pkgs.callPackage ../pkgs/nixos-scripts { };
        gentle-ai = pkgs.callPackage ../pkgs/gentle-ai {
          gentle-ai-src = inputs.gentle-ai-src;
        };
        engram = pkgs.callPackage ../pkgs/engram {
          engram-src = inputs.engram-src;
        };
        gentle-ai-assets = pkgs.callPackage ../pkgs/gentle-ai-assets/default.nix {
          gentle-ai-src = inputs.gentle-ai-src;
        };
        caveman-assets = pkgs.callPackage ../pkgs/caveman-assets/default.nix {
          caveman-src = inputs.caveman-src;
        };
        ponytail-assets = pkgs.callPackage ../pkgs/ponytail-assets/default.nix {
          ponytail-src = inputs.ponytail-src;
        };
        local-ai-assets = pkgs.callPackage ../pkgs/local-ai-assets { };
        engram-assets-vanilla = pkgs.callPackage ../pkgs/engram-assets/vanilla.nix {
          engram-src = inputs.engram-src;
        };
        engram-assets = pkgs.callPackage ../pkgs/engram-assets/default.nix {
          engram = self.engram;
          vanilla = self.engram-assets-vanilla;
        };
        secret-guard-assets = pkgs.callPackage ../pkgs/secret-guard-assets { };
        opencode-npm-packages = pkgs.callPackage ../pkgs/opencode-npm-packages { };
        opencode = pkgs.callPackage ../pkgs/opencode { };
        claude-code = pkgs.callPackage ../pkgs/claude-code {
          claude-code-unwrapped = inputs.claude-code-nix.packages.${pkgs.stdenv.hostPlatform.system}.default;
        };
      };
    in
    self;

  linuxPackages = commonPackages linuxPkgs // {
    openfang = linuxPkgs.callPackage ../pkgs/openfang { };
    thinkfan-ui = linuxPkgs.callPackage ../pkgs/thinkfan-ui {
      thinkfan-ui-src = inputs.thinkfan-ui-src;
      wrapQtAppsHook = linuxPkgs.qt6.wrapQtAppsHook;
      qtbase = linuxPkgs.qt6.qtbase;
      qtsvg = linuxPkgs.qt6.qtsvg;
    };
  };

  darwinPackages = commonPackages darwinPkgs;
in
{
  inherit
    linuxPackages
    darwinPackages
    ;
}
