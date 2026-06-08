# Per-system package definitions and verify-script helpers extracted from flake.nix.
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

  # Shared flake8 ignores for all verify-* scripts.
  # Mirrors the project's ruff/flake8 style: long lines OK, break-before-binary-op OK.
  verifyIgnore = [
    "E501"
    "W503"
    "E265"
    "E266"
    "F702"
  ];

  # Helper: build a verify-* script that calls `nix run` on the resulting derivation.
  # Per-script extra ignore codes (e.g. E226 for ambiguous scalar expressions) are added
  # by callers via `extraIgnore`.
  mkVerifyScript =
    {
      name,
      libraries ? [ ],
      extraIgnore ? [ ],
    }:
    linuxPkgs.writers.writePython3Bin name {
      inherit libraries;
      flakeIgnore = verifyIgnore ++ extraIgnore;
    } (builtins.readFile ./../scripts/${name}.py);

  # Cross-platform shared inputs
  sharedOpencodePaths = {
    extraSkills = ./../shared/opencode/skills;
    extraCommands = ./../shared/opencode/commands;
  };

  linuxPackages = rec {
    nixos-scripts = linuxPkgs.callPackage ../pkgs/nixos-scripts { };
    gentle-ai = linuxPkgs.callPackage ../pkgs/gentle-ai { };
    engram = linuxPkgs.callPackage ../pkgs/engram { };
    gentle-ai-assets-vanilla = linuxPkgs.callPackage ../pkgs/gentle-ai-assets/vanilla.nix {
      gentle-ai-src = inputs.gentle-ai-src;
    };
    gentle-ai-assets = linuxPkgs.callPackage ../pkgs/gentle-ai-assets/default.nix {
      inherit (linuxPkgs) writeText;
      vanilla = linuxPackages.gentle-ai-assets-vanilla;
      inherit (sharedOpencodePaths) extraSkills extraCommands;
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
    openfang = linuxPkgs.callPackage ../pkgs/openfang { };

    # Verify scripts: free-tier + tier-list + opencode-RUN integration tests.
    verify-models = mkVerifyScript {
      name = "verify-models";
      libraries = [ linuxPkgs.python3Packages.openai ];
    };
    verify-tiers = mkVerifyScript {
      name = "verify-tiers";
      libraries = [ linuxPkgs.python3Packages.openai ];
      extraIgnore = [ "E226" ];
    };
    verify-opencode = mkVerifyScript {
      name = "verify-opencode";
      extraIgnore = [ "E226" ];
    };
  };

  darwinPackages = rec {
    gentle-ai = darwinPkgs.callPackage ../pkgs/gentle-ai { };
    engram = darwinPkgs.callPackage ../pkgs/engram { };
    gentle-ai-assets-vanilla = darwinPkgs.callPackage ../pkgs/gentle-ai-assets/vanilla.nix {
      gentle-ai-src = inputs.gentle-ai-src;
    };
    gentle-ai-assets = darwinPkgs.callPackage ../pkgs/gentle-ai-assets/default.nix {
      inherit (darwinPkgs) writeText;
      vanilla = darwinPackages.gentle-ai-assets-vanilla;
      inherit (sharedOpencodePaths) extraSkills extraCommands;
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
  };
in
{
  inherit
    linuxPackages
    darwinPackages
    verifyIgnore
    mkVerifyScript
    ;
}
