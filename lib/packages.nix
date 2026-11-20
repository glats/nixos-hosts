{
  inputs,
  pkgsFor,
  ...
}:
let
  linuxPkgs = pkgsFor "x86_64-linux";
  darwinPkgs = pkgsFor "x86_64-darwin";
  aarch64DarwinPkgs = pkgsFor "aarch64-darwin";

  commonPackages =
    pkgs:
    let
      self = rec {
        nixos-scripts = pkgs.callPackage ../pkgs/nixos-scripts { };
        gentle-ai = pkgs.callPackage ../pkgs/gentle-ai {
          inherit (inputs) gentle-ai-src;
        };
        engram = pkgs.callPackage ../pkgs/engram {
          inherit (inputs) engram-src;
        };
        gentle-ai-assets = pkgs.callPackage ../pkgs/gentle-ai-assets/default.nix {
          inherit (inputs) gentle-ai-src;
          inherit (self) gentle-ai;
        };
        caveman-assets = pkgs.callPackage ../pkgs/caveman-assets/default.nix {
          inherit (inputs) caveman-src;
        };
        ponytail-assets = pkgs.callPackage ../pkgs/ponytail-assets/default.nix {
          inherit (inputs) ponytail-src;
        };
        archify-skill = pkgs.callPackage ../pkgs/archify-skill { };
        local-ai-assets = pkgs.callPackage ../pkgs/local-ai-assets {
          archifySkill = self.archify-skill;
        };
        engram-assets-vanilla = pkgs.callPackage ../pkgs/engram-assets/vanilla.nix {
          inherit (inputs) engram-src;
        };
        engram-assets = pkgs.callPackage ../pkgs/engram-assets/default.nix {
          inherit (self) engram;
          vanilla = self.engram-assets-vanilla;
        };
        opencode-npm-packages-v2 = pkgs.callPackage ../pkgs/opencode-npm-packages-v2 { };
        browsermcp-v2 = pkgs.callPackage ../pkgs/browsermcp-v2 { };
        opencode-quota-patched = pkgs.callPackage ../pkgs/opencode-quota-patched { };
        opencode = pkgs.callPackage ../pkgs/opencode { };
        leaf = pkgs.callPackage ../pkgs/leaf { };
        herdr = pkgs.callPackage ../pkgs/herdr { };
        claude-code = pkgs.callPackage ../pkgs/claude-code {
          # claude-code-nix exports no x86_64-darwin package: its
          # nix-systems/default input lists only aarch64-darwin,
          # aarch64-linux and x86_64-linux, even though its package.nix
          # supports the darwin-x64 binary. Build that package directly for
          # the systems the flake does not export.
          claude-code-unwrapped =
            inputs.claude-code-nix.packages.${pkgs.stdenv.hostPlatform.system}.default
              or (pkgs.callPackage "${inputs.claude-code-nix}/package.nix" { });
        };
        inherit (pkgs) rtk;
      };
    in
    self;

  linuxPackages = commonPackages linuxPkgs // {
    openfang = linuxPkgs.callPackage ../pkgs/openfang { };
    mcp-supermercados-cl = linuxPkgs.callPackage ../pkgs/mcp-supermercados-cl { };
    dolt = linuxPkgs.callPackage ../pkgs/dolt { };
    beads = linuxPkgs.callPackage ../pkgs/beads { };
    gastown = linuxPkgs.callPackage ../pkgs/gastown {
      inherit (linuxPackages) beads;
      inherit (linuxPackages) dolt;
    };
    gastown-run = linuxPkgs.callPackage ../pkgs/gastown-run {
      inherit (linuxPackages) nixos-scripts;
      inherit (linuxPackages) gastown;
      inherit (linuxPackages) beads;
    };
    thinkfan-ui = linuxPkgs.callPackage ../pkgs/thinkfan-ui {
      inherit (inputs) thinkfan-ui-src;
      wrapQtAppsHook = linuxPkgs.qt6.wrapQtAppsHook;
      qtbase = linuxPkgs.qt6.qtbase;
      qtsvg = linuxPkgs.qt6.qtsvg;
    };
  };

  darwinPackages = commonPackages darwinPkgs;
  aarch64DarwinPackages = commonPackages aarch64DarwinPkgs;
in
{
  inherit
    linuxPackages
    darwinPackages
    aarch64DarwinPackages
    ;
}
