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
{ inputs
, pkgsFor
, ...
}:
let
  linuxPkgs = pkgsFor "x86_64-linux";
  darwinPkgs = pkgsFor "x86_64-darwin";

  linuxPackages = rec {
    nixos-scripts = linuxPkgs.callPackage ../pkgs/nixos-scripts { };
    gentle-ai = linuxPkgs.callPackage ../pkgs/gentle-ai {
      gentle-ai-src = inputs.gentle-ai-src;
    };
    engram = linuxPkgs.callPackage ../pkgs/engram {
      engram-src = inputs.engram-src;
    };
    gentle-ai-assets = linuxPkgs.callPackage ../pkgs/gentle-ai-assets/default.nix {
      gentle-ai-src = inputs.gentle-ai-src;
    };
    caveman-assets = linuxPkgs.callPackage ../pkgs/caveman-assets/default.nix {
      caveman-src = inputs.caveman-src;
    };
    ponytail-assets = linuxPkgs.callPackage ../pkgs/ponytail-assets/default.nix {
      ponytail-src = inputs.ponytail-src;
    };
    local-ai-assets = linuxPkgs.callPackage ../pkgs/local-ai-assets { };
    engram-assets-vanilla = linuxPkgs.callPackage ../pkgs/engram-assets/vanilla.nix {
      engram-src = inputs.engram-src;
    };
    engram-assets = linuxPkgs.callPackage ../pkgs/engram-assets/default.nix {
      engram = linuxPackages.engram;
      vanilla = linuxPackages.engram-assets-vanilla;
    };
    secret-guard-assets = linuxPkgs.callPackage ../pkgs/secret-guard-assets { };
    opencode-npm-packages = linuxPkgs.callPackage ../pkgs/opencode-npm-packages { };
    opencode = linuxPkgs.callPackage ../pkgs/opencode { };
    openfang = linuxPkgs.callPackage ../pkgs/openfang { };
    claude-code = linuxPkgs.callPackage ../pkgs/claude-code {
      claude-code-unwrapped = inputs.claude-code-nix.packages.x86_64-linux.default;
    };
    thinkfan-ui = linuxPkgs.callPackage ../pkgs/thinkfan-ui {
      thinkfan-ui-src = inputs.thinkfan-ui-src;
      wrapQtAppsHook = linuxPkgs.qt6.wrapQtAppsHook;
      qtbase = linuxPkgs.qt6.qtbase;
      qtsvg = linuxPkgs.qt6.qtsvg;
    };
  };

  darwinPackages = rec {
    nixos-scripts = darwinPkgs.callPackage ../pkgs/nixos-scripts { };
    gentle-ai = darwinPkgs.callPackage ../pkgs/gentle-ai {
      gentle-ai-src = inputs.gentle-ai-src;
    };
    engram = darwinPkgs.callPackage ../pkgs/engram {
      engram-src = inputs.engram-src;
    };
    gentle-ai-assets = darwinPkgs.callPackage ../pkgs/gentle-ai-assets/default.nix {
      gentle-ai-src = inputs.gentle-ai-src;
    };
    caveman-assets = darwinPkgs.callPackage ../pkgs/caveman-assets/default.nix {
      caveman-src = inputs.caveman-src;
    };
    ponytail-assets = darwinPkgs.callPackage ../pkgs/ponytail-assets/default.nix {
      ponytail-src = inputs.ponytail-src;
    };
    local-ai-assets = darwinPkgs.callPackage ../pkgs/local-ai-assets { };
    engram-assets-vanilla = darwinPkgs.callPackage ../pkgs/engram-assets/vanilla.nix {
      engram-src = inputs.engram-src;
    };
    engram-assets = darwinPkgs.callPackage ../pkgs/engram-assets/default.nix {
      engram = darwinPackages.engram;
      vanilla = darwinPackages.engram-assets-vanilla;
    };
    secret-guard-assets = darwinPkgs.callPackage ../pkgs/secret-guard-assets { };
    opencode-npm-packages = darwinPkgs.callPackage ../pkgs/opencode-npm-packages { };
    opencode = darwinPkgs.callPackage ../pkgs/opencode { };
    claude-code = darwinPkgs.callPackage ../pkgs/claude-code {
      claude-code-unwrapped = inputs.claude-code-nix.packages.x86_64-darwin.default;
    };
  };
in
{
  inherit
    linuxPackages
    darwinPackages
    ;
}
