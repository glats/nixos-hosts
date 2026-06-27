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

  # Platform-specific FOD hashes for node_modules.
  # bun installs platform-specific deps (esbuild, etc.) so hashes differ.
  opencodeNodeModulesHashes = {
    x86_64-linux = "sha256-7NVMnjK24+42ti8nz+dXlTE5mocqO8LlfI3HevbyZJc=";
    x86_64-darwin = "sha256-wpffD8nTebCVg+JnffB3BERh8L5jKD/YMg4kw2qwV60=";
  };

  opencodeFor =
    system:
    let
      upstream =
        inputs.opencode-src.packages.${system}.opencode or (throw "opencode not available for ${system}");
      # Work around bun bug oven-sh/bun#19088: --frozen-lockfile falsely
      # reports "lockfile had changes" when bun version differs from what
      # generated the lockfile (nixpkgs has 1.3.13, upstream expects 1.3.14).
      # Remove the flag and pin the recomputed FOD hash.
      patchedNodeModules = upstream.node_modules.overrideAttrs (oldAttrs: {
        buildPhase = builtins.replaceStrings [ "--frozen-lockfile" ] [ "" ] oldAttrs.buildPhase;
        outputHash = opencodeNodeModulesHashes.${system} or (throw "no opencode node_modules hash for ${system}");
      });
    in
    (upstream.override { node_modules = patchedNodeModules; }).overrideAttrs (oldAttrs: {
      postPatch = (oldAttrs.postPatch or "") + ''
        # Relax bun version requirement (nixpkgs has 1.3.13, opencode wants 1.3.14)
        if [ -f packages/script/src/index.ts ]; then
          sed -i 's/expectedBunVersion = .*/expectedBunVersion = "1.3.13"/' packages/script/src/index.ts || true
        fi
        # Also check for any other bun version checks
        # Use grep -r (no xargs) so an empty match returns non-zero cleanly, and || true on the whole chain
        grep -rl "bun@.*1.3.14" --include="*.ts" --include="*.js" . 2>/dev/null | while read f; do
          sed -i 's/bun@.*1.3.14/bun@1.3.13/g' "$f" || true
        done || true
      '';
    });

  # Cross-platform shared inputs
  sharedOpencodePaths = {
    extraSkills = ./../shared/opencode/skills;
    # extraCommands: no local command forks; commands come from upstream
    # gentle-ai-src and caveman-src via gentle-ai-assets-vanilla.
  };

  linuxPackages = rec {
    nixos-scripts = linuxPkgs.callPackage ../pkgs/nixos-scripts { };
    gentle-ai = linuxPkgs.callPackage ../pkgs/gentle-ai { };
    engram = linuxPkgs.callPackage ../pkgs/engram { };
    gentle-ai-assets-vanilla = linuxPkgs.callPackage ../pkgs/gentle-ai-assets/vanilla.nix {
      gentle-ai-src = inputs.gentle-ai-src;
      caveman-src = inputs.caveman-src;
    };
    gentle-ai-assets = linuxPkgs.callPackage ../pkgs/gentle-ai-assets/default.nix {
      vanilla = linuxPackages.gentle-ai-assets-vanilla;
      inherit (sharedOpencodePaths) extraSkills;
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
    opencode = opencodeFor "x86_64-linux";
    openfang = linuxPkgs.callPackage ../pkgs/openfang { };
  };

  darwinPackages = rec {
    gentle-ai = darwinPkgs.callPackage ../pkgs/gentle-ai { };
    engram = darwinPkgs.callPackage ../pkgs/engram { };
    gentle-ai-assets-vanilla = darwinPkgs.callPackage ../pkgs/gentle-ai-assets/vanilla.nix {
      gentle-ai-src = inputs.gentle-ai-src;
      caveman-src = inputs.caveman-src;
    };
    gentle-ai-assets = darwinPkgs.callPackage ../pkgs/gentle-ai-assets/default.nix {
      vanilla = darwinPackages.gentle-ai-assets-vanilla;
      inherit (sharedOpencodePaths) extraSkills;
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
    opencode = opencodeFor "x86_64-darwin";
  };
in
{
  inherit
    linuxPackages
    darwinPackages
    ;
}
