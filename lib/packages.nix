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

  # Cross-platform shared inputs
  sharedOpencodePaths = {
    extraSkills = ./../shared/opencode/skills;
    # Arbitrary file overrides layered on top of vanilla gentle-ai assets.
    # Directory structure MUST mirror $out/share/gentle-ai/ (e.g.
    # shared/opencode/assets/opencode/sdd-orchestrator.md overwrites
    # $out/share/gentle-ai/opencode/sdd-orchestrator.md).
    extraAssets = ./../shared/opencode/assets;
    # extraCommands: no local command forks; commands come from upstream
    # gentle-ai-src and caveman-src via gentle-ai-assets-vanilla.
  };

  linuxPackages = rec {
    nixos-scripts = linuxPkgs.callPackage ../pkgs/nixos-scripts { };
    gentle-ai = linuxPkgs.callPackage ../pkgs/gentle-ai {
      gentle-ai-src = inputs.gentle-ai-src;
    };
    engram = linuxPkgs.callPackage ../pkgs/engram {
      engram-src = inputs.engram-src;
    };
    gentle-ai-assets-vanilla = linuxPkgs.callPackage ../pkgs/gentle-ai-assets/vanilla.nix {
      gentle-ai-src = inputs.gentle-ai-src;
      caveman-src = inputs.caveman-src;
      ponytail-src = inputs.ponytail-src;
    };
    gentle-ai-assets = linuxPkgs.callPackage ../pkgs/gentle-ai-assets/default.nix {
      vanilla = linuxPackages.gentle-ai-assets-vanilla;
      inherit (sharedOpencodePaths) extraSkills extraAssets;
    };
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
    claude-code = inputs.claude-code-nix.packages.x86_64-linux.default;
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
    gentle-ai-assets-vanilla = darwinPkgs.callPackage ../pkgs/gentle-ai-assets/vanilla.nix {
      gentle-ai-src = inputs.gentle-ai-src;
      caveman-src = inputs.caveman-src;
      ponytail-src = inputs.ponytail-src;
    };
    gentle-ai-assets = darwinPkgs.callPackage ../pkgs/gentle-ai-assets/default.nix {
      vanilla = darwinPackages.gentle-ai-assets-vanilla;
      inherit (sharedOpencodePaths) extraSkills extraAssets;
    };
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
    claude-code = inputs.claude-code-nix.packages.x86_64-darwin.default;
  };
in
{
  inherit
    linuxPackages
    darwinPackages
    ;
}
