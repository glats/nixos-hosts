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
      # Consumer boundary for the Quattro-capable main line. Its nested
      # quattro inputs remain independent; the host still evaluates against
      # this flake's nixpkgs 26.05.
      url = "github:glats/omarchy-nix/5c01ca65d42d520f45d2fb2ddd2526eb6e10494d";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
      inputs.quattro-nixpkgs.follows = "t14-nixpkgs";
      inputs.quattro-home-manager.follows = "t14-home-manager";
      inputs.quattro-hyprland.follows = "t14-hyprland";
      inputs.quickshell.follows = "t14-quickshell";
    };

    # Quattro's newer Linux-only dependency boundary. These inputs are routed
    # exclusively to t14; the shared inputs remain on 26.05 for every other
    # host, including the Intel mact2 configuration.
    t14-nixpkgs.url = "github:NixOS/nixpkgs/ef34387ddd751e1ab8857adf4676492d32eb24ec";
    t14-home-manager = {
      url = "github:nix-community/home-manager/cda90fd8838825c689fde9d3f3b4e937937790df";
      inputs.nixpkgs.follows = "t14-nixpkgs";
    };
    t14-hyprland = {
      url = "github:hyprwm/Hyprland/efb50993780079460b0cbed1363e2166a2de1d9f";
      inputs.nixpkgs.follows = "t14-nixpkgs";
    };
    t14-quickshell = {
      url = "github:quickshell-mirror/quickshell/1a4716cde794a59928d9d9fc15f2afc7a95de360";
      inputs.nixpkgs.follows = "t14-nixpkgs";
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
    # Pinned to v2.5.0 tag (release f5dd1a6c) — do not track main.
    gentle-ai-src = {
      url = "github:Gentleman-Programming/gentle-ai/v2.5.0";
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
    inputs@{
      self,
      nixpkgs,
      home-manager,
      ...
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

      mkPkgsFor =
        nixpkgsInput: extraOverlays: s:
        import nixpkgsInput {
          system = s;
          config.allowUnfree = true;
          overlays =
            (if nixpkgsInput.lib.hasSuffix "linux" s then [ linuxOverlay ] else [ darwinOverlay ])
            ++ extraOverlays;
        };

      pkgsFor = mkPkgsFor nixpkgs [ ];

      # Quattro packages are exposed by omarchy-nix's matching input set and
      # overlaid only into t14. This keeps the global nixpkgs boundary intact,
      # especially for the Intel mact2 configuration.
      t14QuattroOverlay = final: _prev: {
        omarchy-runtime = inputs.omarchy-nix.packages.${final.system}.omarchy-runtime;
        quickshell = inputs.omarchy-nix.packages.${final.system}.quickshell;
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
        aarch64DarwinPackages
        ;

      # --- Home module lists ---
      # Canonical base list of shared Home Manager modules for Linux. See
      # `linux/home/shared-modules.nix` for the full list.
      # Shared lists are imported by each platform/host Home Manager entry.
      linuxHomeModules = import ./linux/home/shared-modules.nix {
        inherit inputs;
      };

      darwinHomeModules = import ./darwin/home/shared-modules.nix {
        inherit inputs;
      };

      # --- mkHomeConfig: standalone home-manager for any platform ---
      mkHomeConfig =
        {
          hostname,
          system,
          username,
          githubUser ? "jcuzmar",
          extraModules,
          nixpkgsInput ? nixpkgs,
          homeManagerInput ? home-manager,
          extraOverlays ? [ ],
        }:
        let
          hostInputs = inputs // {
            nixpkgs = nixpkgsInput;
            home-manager = homeManagerInput;
          };
        in
        homeManagerInput.lib.homeManagerConfiguration {
          pkgs = mkPkgsFor nixpkgsInput extraOverlays system;
          # `extraModules` is the complete per-host module list. Do not prepend
          # a platform-wide list: host/default.nix already composes it, and
          # prepending would evaluate shared modules twice.
          modules = extraModules;
          extraSpecialArgs = {
            inherit username;
            inputs = hostInputs;
            host = hostname;
            hostName = hostname;
            # Darwin-specific extras (ignored by linux modules)
            primaryUser = username;
            inherit githubUser;
            javaVersion = "temurin-25.0.1+8.0.LTS";
          };
        };
    in
    {
      packages.x86_64-linux = linuxPackages;

      packages.x86_64-darwin = darwinPackages;
      packages.aarch64-darwin = aarch64DarwinPackages;

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
        mact2 = mkDarwinHost { configName = "mact2"; };
        macm5 = mkDarwinHost {
          configName = "macm5";
          system = "aarch64-darwin";
          primaryUser = "juan";
          githubUser = "jcuzmar";
        };
      };

      # --- Standalone home-manager configurations ---
      homeConfigurations =
        let
          baseHomeConfig =
            {
              hostname,
              system,
              username,
              githubUser ? "jcuzmar",
              extraModules,
              nixpkgsInput ? nixpkgs,
              homeManagerInput ? home-manager,
              extraOverlays ? [ ],
            }:
            mkHomeConfig {
              inherit
                hostname
                system
                username
                githubUser
                extraModules
                nixpkgsInput
                homeManagerInput
                extraOverlays
                ;
            };
        in
        {
          # Standalone HM entries use the same wrapper so hostname, system,
          # username, and extra modules are passed consistently.
          rog = baseHomeConfig {
            hostname = "rog";
            system = "x86_64-linux";
            username = "glats";
            extraModules = import ./hosts/rog/home/default.nix { inherit inputs; };
          };
          thinkcentre = baseHomeConfig {
            hostname = "thinkcentre";
            system = "x86_64-linux";
            username = "glats";
            extraModules = import ./hosts/thinkcentre/home/default.nix { inherit inputs; };
          };
          # t14 appends the omarchy config block that the NixOS path provides
          # via osConfig (standalone HM has no osConfig).
          t14 = baseHomeConfig {
            hostname = "t14";
            system = "x86_64-linux";
            username = "glats";
            extraModules = import ./hosts/t14/home/default.nix { inherit inputs; } ++ [
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
          };
          mact2 = baseHomeConfig {
            hostname = "mact2";
            system = "x86_64-darwin";
            username = "jcuzmar";
            extraModules = [
              # Include home-darwin/default.nix so the standalone
              # home-manager build for mact2 picks up the per-host base
              # config (home.username, home.homeDirectory, etc.) on top of
              # the canonical module list from `darwinHomeModules`.
              ./darwin/home
              {
                # Native OpenAI tier via the sing-box private link (scoped
                # bin/opencode-home launcher; see hosts/mact2/default.nix).
                home.opencode.activeProviderName = "openai-medium";
              }
            ];
          };
          macm5 = baseHomeConfig {
            hostname = "macm5";
            system = "aarch64-darwin";
            username = "juan";
            githubUser = "jcuzmar";
            extraModules = [
              ./darwin/home
              {
                home.opencode.activeProviderName = "anthropic-opencode-free";
              }
            ];
          };
        };

      # --- Formatter ---
      # Use through `nix fmt -- <path>` in this repo.
      # Keep this aligned with `format-nix`; do not invoke formatter binaries directly.
      formatter.x86_64-linux = nixpkgs.legacyPackages.x86_64-linux.nixfmt-tree;
      formatter.x86_64-darwin = nixpkgs.legacyPackages.x86_64-darwin.nixfmt-tree;
      formatter.aarch64-darwin = nixpkgs.legacyPackages.aarch64-darwin.nixfmt-tree;

      # --- Go toolchain devshell (pkgs/nixos-scripts) ---
      # Dev iteration only: `nix develop -c go -C pkgs/nixos-scripts test ./...`
      # or `nix develop -c go -C pkgs/nixos-scripts run ./cmd/<name>`.
      # Deployed binaries are always the Nix-built ones (buildGoModule).
      devShells.x86_64-linux.default = nixpkgs.legacyPackages.x86_64-linux.mkShell {
        packages = with nixpkgs.legacyPackages.x86_64-linux; [ go ];
      };
      devShells.x86_64-darwin.default = nixpkgs.legacyPackages.x86_64-darwin.mkShell {
        packages = with nixpkgs.legacyPackages.x86_64-darwin; [ go ];
      };
    };
}
