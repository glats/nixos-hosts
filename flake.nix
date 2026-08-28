{
  description = "Unified Nix configuration for NixOS and macOS hosts";

  inputs = {
    # Unified nixpkgs 26.05 for all hosts (NixOS + Darwin).
    # 26.11 dropped x86_64-darwin — mact2 (Intel Mac) stays on 26.05
    # until hardware upgrade to Apple Silicon. Security fixes until end of 2026.
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

    home-manager = {
      url = "github:nix-community/home-manager/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-colors.url = "github:misterio77/nix-colors";

    omarchy-nix = {
      url = "github:glats/omarchy-nix/main";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };

    # nixos-hardware — community-maintained hardware profiles.
    # t14 imports the lenovo-thinkpad-t14-amd-gen4 profile via extraModules
    # to merge with the existing hardware-configuration.nix (preserves
    # btrfs subvolumes, swap, and EFI) and modules/hardware/amd-laptop.nix
    # (provides fwupd, zramSwap, power-profiles-daemon).
    nixos-hardware = {
      url = "github:NixOS/nixos-hardware/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # HyprDynamicMonitors — Hyprland monitor profile daemon with
    # UPower lid-event support and EDID-based description matching.
    hyprdynamicmonitors = {
      url = "github:fiffeek/hyprdynamicmonitors";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # gentle-ai upstream (for skills, commands, plugins)
    gentle-ai-src = {
      url = "github:Gentleman-Programming/gentle-ai/main";
      flake = false;
    };

    # Caveman ultra-compressed communication skills
    caveman-src = {
      url = "github:JuliusBrussee/caveman";
      flake = false;
    };

    # Ponytail — teaches agents to write less code (YAGNI enforcement)
    ponytail-src = {
      url = "github:DietrichGebert/ponytail";
      flake = false;
    };

    # Claude Code — auto-updating flake from sadjow, always latest binary from GCS
    claude-code-nix = {
      url = "github:sadjow/claude-code-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # engram upstream (for OpenCode plugin)
    engram-src = {
      url = "github:Gentleman-Programming/engram/main";
      flake = false;
    };

    # --- NixOS-only inputs ---
    asus-fan-control-src = {
      url = "github:dominiksalvet/asus-fan-control";
      flake = false;
    };

    pipewire-module-xrdp-src = {
      url = "github:neutrinolabs/pipewire-module-xrdp";
      flake = false;
    };

    # thinkfan-ui — PyQt6 GUI for ThinkPad fan control
    # (writes to /proc/acpi/ibm/fan; mutually exclusive with services.thinkfan)
    thinkfan-ui-src = {
      url = "github:zocker-160/thinkfan-ui";
      flake = false;
    };

    # --- macOS-only inputs ---
    # nix-darwin must match the nixpkgs release: 26.05 for mact2.
    nix-darwin = {
      url = "github:nix-darwin/nix-darwin/nix-darwin-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Determinate 3.* module
    determinate = {
      url = "https://flakehub.com/f/DeterminateSystems/determinate/3";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # nix-homebrew -- brew-src pinned to commit that fixes `to_sym for nil` crash
    nix-homebrew = {
      url = "github:zhaofengli/nix-homebrew";
      inputs.brew-src.follows = "homebrew-brew";
    };
    homebrew-brew = {
      # Master incluye fix de `to_sym for nil` y `--force-cleanup` (nix-darwin requerido)
      url = "github:Homebrew/brew/master";
      flake = false;
    };

    # VS Code extensions as Nix — darwin-only (mact2).
    # Gated behind isDarwin in darwin/home/vscode.nix so Linux evals skip it.
    # Pinned to 1c7bb95: the last commit before x86_64-darwin was dropped
    # (nix-vscode-extensions PR #187, merged 2026-07-22).
    nix-vscode-extensions = {
      url = "github:nix-community/nix-vscode-extensions/1c7bb95446387973178363916a51b14515fa5ee4";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    ghostty = {
      url = "github:ghostty-org/ghostty";
      inputs.nixpkgs.follows = "nixpkgs";
    };

  };

  outputs =
    inputs@{ self
    , nixpkgs
    , home-manager
    , ...
    }:
    let
      # --- Builders ---
      inherit (import ./lib/mkHost.nix { inherit inputs self; }) mkNixosHost mkHost;
      inherit (import ./lib/mkDarwinHost.nix { inherit inputs self; }) mkDarwinHost;

      # --- Overlay selection by system ---
      linuxOverlay = import ./overlays/linux.nix {
        inherit self inputs;
      };
      darwinOverlay = import ./overlays/darwin.nix {
        inherit inputs self;
      };

      pkgsFor =
        s:
        import nixpkgs {
          system = s;
          config.allowUnfree = true;
          overlays = if nixpkgs.lib.hasSuffix "linux" s then [ linuxOverlay ] else [ darwinOverlay ];
        };

      # Per-system package definitions.
      # See lib/packages.nix for the full interface.
      packages = import ./lib/packages.nix {
        inherit inputs;
        pkgsFor = pkgsFor;
      };
      inherit (packages)
        linuxPackages
        darwinPackages
        ;

      # --- Home module lists ---
      # Canonical base list of shared Home Manager modules for Linux. See
      # `linux/home/shared-modules.nix` for the full list.
      # NOTE: After the Linux HM composition alignment refactor,
      # `linuxHomeModules` is no longer the sync mechanism for Linux
      # standalone entries. `rog` and `thinkcentre` now import their
      # per-host `hosts/<host>/home/default.nix` files directly, and the
      # NixOS-integrated path (`linux/system/base/home-manager.nix`) does the same.
      # This binding is retained because `mkHomeConfig` still references it in
      # the platform-conditional branch.
      linuxHomeModules = import ./linux/home/shared-modules.nix {
        inherit inputs;
      };

      darwinHomeModules = import ./darwin/home/shared-modules.nix {
        inherit inputs;
      };

      # --- mkHomeConfig: standalone home-manager for any platform ---
      mkHomeConfig =
        hostname: system: username: extraModules:
        home-manager.lib.homeManagerConfiguration {
          pkgs = pkgsFor system;
          modules =
            (if nixpkgs.lib.hasSuffix "linux" system then linuxHomeModules else darwinHomeModules)
            ++ extraModules;
          extraSpecialArgs = {
            inherit inputs username;
            hostName = hostname;
            # Darwin-specific extras (ignored by linux modules)
            primaryUser = username;
            javaVersion = "temurin-25.0.1+8.0.LTS";
          };
        };
    in
    {
      packages.x86_64-linux = linuxPackages;

      packages.x86_64-darwin = darwinPackages;

      # --- Apps for nix run ---
      apps.x86_64-linux = {
        nixos-build = {
          type = "app";
          program = "${linuxPackages.nixos-scripts}/bin/nixos-build";
          meta = {
            description = "Build and switch NixOS configuration";
            category = "system";
          };
        };
      };

      # --- Checks ---
      checks.x86_64-linux = {
        rog = self.nixosConfigurations.rog.config.system.build.toplevel;
        thinkcentre = self.nixosConfigurations.thinkcentre.config.system.build.toplevel;
        t14 = self.nixosConfigurations.t14.config.system.build.toplevel;
      };

      # --- NixOS configurations ---
      nixosConfigurations = {
        rog = mkNixosHost { hostname = "rog"; };
        thinkcentre = mkNixosHost { hostname = "thinkcentre"; };
        t14 = mkNixosHost {
          hostname = "t14";
          # Omarchy + hardware-specific modules.
          #   - omarchy-nix: Hyprland-based desktop environment (NixOS module).
          #   - nixos-hardware T14 AMD gen4 profile: amdgpu initrd, 32-bit
          #     graphics, fstrim, amd_pstate=active, backlight, touchpad.
          # Both modules use mkDefault for overlapping settings (graphics,
          # microcode) so they merge cleanly with hardware-configuration.nix
          # and modules/hardware/amd-laptop.nix.
          extraModules = [
            inputs.omarchy-nix.nixosModules.default
            inputs.nixos-hardware.nixosModules.lenovo-thinkpad-t14-amd-gen4
          ];
        };
      };

      # --- Darwin configurations ---
      darwinConfigurations = {
        mact2 = mkDarwinHost { hostname = "mact2"; };
      };

      # --- Standalone home-manager configurations ---
      homeConfigurations =
        let
          baseHomeConfig =
            hostname: system: username: extraModules:
            mkHomeConfig hostname system username extraModules;
        in
        {
          # Standalone HM entries use the same wrapper so hostname, system,
          # username, and extra modules are passed consistently.
          rog = baseHomeConfig "rog" "x86_64-linux" "glats" (
            import ./hosts/rog/home/default.nix { inherit inputs; }
          );
          thinkcentre = baseHomeConfig "thinkcentre" "x86_64-linux" "glats" (
            import ./hosts/thinkcentre/home/default.nix { inherit inputs; }
          );
          # t14 appends the omarchy config block that the NixOS path provides
          # via osConfig (standalone HM has no osConfig).
          t14 = baseHomeConfig "t14" "x86_64-linux" "glats" (
            import ./hosts/t14/home/default.nix { inherit inputs; }
            ++ [
              {
                omarchy = {
                  theme = "glats";
                  username = "glats";
                  full_name = "Glats";
                  email_address = "glats@local";
                  browser = "brave";
                  terminal = "ghostty";
                  monitors = [ "eDP-1,preferred,auto,1" ];
                  scale = 1;
                  light_theme_detection.enable = false;
                  wayvnc.enable = true;
                };
              }
            ]
          );
          mact2 = baseHomeConfig "mact2" "x86_64-darwin" "jcuzmar" [
            # Include home-darwin/default.nix so the standalone
            # home-manager build for mact2 picks up the per-host base
            # config (home.username, home.homeDirectory, etc.) on top of
            # the canonical module list from `darwinHomeModules`.
            ./darwin/home
            {
              home.opencode.activeProviderName = "opencode-go-medium";
            }
          ];
        };

      # --- Formatter ---
      # Use through `nix fmt -- <path>` in this repo.
      # Keep this aligned with `format-nix`; do not invoke formatter binaries directly.
      formatter.x86_64-linux = nixpkgs.legacyPackages.x86_64-linux.nixpkgs-fmt;
      formatter.x86_64-darwin = nixpkgs.legacyPackages.x86_64-darwin.nixpkgs-fmt;
    };
}
