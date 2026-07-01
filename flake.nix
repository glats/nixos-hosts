{
  description = "Unified Nix configuration for NixOS and macOS hosts";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

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
    nix-darwin = {
      url = "github:nix-darwin/nix-darwin/master";
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

    # VS Code extensions as Nix
    nix-vscode-extensions = {
      url = "github:nix-community/nix-vscode-extensions";
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
      # Canonical base list of shared Home Manager modules. See
      # `home-linux/shared-modules.nix` for the full list. The
      # NixOS-integrated home-manager module (`modules/base/home-manager.nix`)
      # imports the same list, so both code paths stay in sync.
      linuxHomeModules = import ./home-linux/shared-modules.nix {
        inherit inputs;
      };

      darwinHomeModules = import ./home-darwin/shared-modules.nix {
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
          rog = baseHomeConfig "rog" "x86_64-linux" "glats" [
            ./home-linux/conky-rog.nix
            ./home-linux/openfang.nix
          ];
          thinkcentre = baseHomeConfig "thinkcentre" "x86_64-linux" "glats" [
            ./home-linux/conky-thinkcentre.nix
          ];
          # t14 uses NixOS-integrated HM.  The standalone entry is
          # required by the `hms` alias (home-manager switch --flake .#t14).
          # omarchy.nix is self-contained (imports omarchy-nix HM module
          # + selective shared modules) so we do NOT use baseHomeConfig
          # (which would prepend linuxHomeModules and cause duplicate
          # module errors).
          #
          # The omarchy-nix HM module copies osConfig.omarchy into HM
          # config (lib.mkIf (osConfig ? omarchy) { ... omarchy = osConfig.omarchy or {}; ... }).
          # In standalone HM, osConfig = {} so the sync short-circuits.
          # We inject the necessary omarchy values explicitly here to
          # match what the NixOS path provides.
          t14 = home-manager.lib.homeManagerConfiguration {
            pkgs = pkgsFor "x86_64-linux";
            modules = [
              ./hosts/t14/home/omarchy.nix
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
            ];
            extraSpecialArgs = {
              inherit inputs;
              hostName = "t14";
              username = "glats";
            };
          };
          mact2 = baseHomeConfig "mact2" "x86_64-darwin" "jcuzmar" [
            # Include home-darwin/default.nix so the standalone
            # home-manager build for mact2 picks up the per-host base
            # config (home.username, home.homeDirectory, etc.) on top of
            # the canonical module list from `darwinHomeModules`.
            ./home-darwin
          ];
        };

      # --- Formatter ---
      # Use through `nix fmt -- <path>` in this repo.
      # Do not invoke `nixfmt-rfc-style` directly; the executable is `nixfmt`.
      formatter.x86_64-linux = nixpkgs.legacyPackages.x86_64-linux.nixfmt;
      formatter.x86_64-darwin = nixpkgs.legacyPackages.x86_64-darwin.nixfmt;
    };
}
