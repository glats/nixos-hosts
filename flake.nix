{
  description = "Unified Nix configuration for NixOS and macOS hosts";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

    home-manager = {
      url = "github:nix-community/home-manager/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    sonic-de = {
      url = "github:sonicde-nixos/sonic-flake/d779fe69d144f9ef270887e71a16cae4cab7a741";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-colors.url = "github:misterio77/nix-colors";

    omarchy-nix = {
      url = "github:glats/omarchy-nix/5fc93f4c86f4766e477b7e94776e4a7c25ed3579";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
      inputs.quattro-nixpkgs.follows = "t14-nixpkgs";
      inputs.quattro-home-manager.follows = "t14-home-manager";
      inputs.quattro-hyprland.follows = "t14-hyprland";
      inputs.quickshell.follows = "t14-quickshell";
    };

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

    nixos-hardware = {
      url = "github:NixOS/nixos-hardware/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    openlogi = {
      url = "github:AprilNEA/OpenLogi/7a9d092a7dda0cb3b7ec18ada4424d681fca65ca";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    hyprdynamicmonitors = {
      url = "github:fiffeek/hyprdynamicmonitors";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    gentle-ai-src = {
      url = "github:Gentleman-Programming/gentle-ai/898d3976e8049a7238eaa7de60bff325c30d2b3d";
      flake = false;
    };

    caveman-src = {
      url = "github:JuliusBrussee/caveman";
      flake = false;
    };

    ponytail-src = {
      url = "github:DietrichGebert/ponytail";
      flake = false;
    };

    claude-code-nix = {
      url = "github:sadjow/claude-code-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    engram-src = {
      url = "github:Gentleman-Programming/engram/main";
      flake = false;
    };

    asus-fan-control-src = {
      url = "github:dominiksalvet/asus-fan-control";
      flake = false;
    };

    pipewire-module-xrdp-src = {
      url = "github:neutrinolabs/pipewire-module-xrdp";
      flake = false;
    };

    thinkfan-ui-src = {
      url = "github:zocker-160/thinkfan-ui";
      flake = false;
    };

    nix-darwin = {
      url = "github:nix-darwin/nix-darwin/nix-darwin-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    determinate = {
      url = "https://flakehub.com/f/DeterminateSystems/determinate/3";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-homebrew = {
      url = "github:zhaofengli/nix-homebrew";
      inputs.brew-src.follows = "homebrew-brew";
    };
    homebrew-brew = {
      url = "github:Homebrew/brew/master";
      flake = false;
    };

    ghostty = {
      url = "github:ghostty-org/ghostty";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-vscode-extensions = {
      url = "github:nix-community/nix-vscode-extensions";
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
      inherit (import ./lib/mkHost.nix { inherit inputs self; }) mkNixosHost mkHost;
      inherit (import ./lib/mkDarwinHost.nix { inherit inputs self; }) mkDarwinHost;

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

      t14QuattroOverlay = final: _prev: {
        omarchy-runtime = inputs.omarchy-nix.packages.${final.system}.omarchy-runtime;
        quickshell = inputs.omarchy-nix.packages.${final.system}.quickshell;
      };

      packages = import ./lib/packages.nix {
        inherit inputs;
        pkgsFor = pkgsFor;
      };
      inherit (packages)
        linuxPackages
        darwinPackages
        aarch64DarwinPackages
        ;

      linuxHomeModules = import ./linux/home/shared-modules.nix {
        inherit inputs;
      };

      darwinHomeModules = import ./darwin/home/shared-modules.nix {
        inherit inputs;
      };

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
          modules = extraModules;
          extraSpecialArgs = {
            inherit username;
            inputs = hostInputs;
            host = hostname;
            hostName = hostname;
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

      checks.x86_64-linux.format =
        let
          pkgs = nixpkgs.legacyPackages.x86_64-linux;
        in
        pkgs.runCommand "nix-format-check" { nativeBuildInputs = [ pkgs.nixfmt-tree ]; } ''
          cp -r ${self} source
          chmod -R u+w source
          cd source
          treefmt --ci --walk filesystem --tree-root .
          touch $out
        '';

      checks.x86_64-linux.opencode-agent-schema =
        let
          pkgs = nixpkgs.legacyPackages.x86_64-linux;
          config = self.homeConfigurations.rog.config.home.file.".config/opencode/opencode.json".source;
        in
        pkgs.runCommand "opencode-agent-schema" { nativeBuildInputs = [ pkgs.jq ]; } ''
          jq -e '
            (.agents["gentle-orchestrator"].mode == "primary") and
            (.agents["gentle-ai-explore"].mode == "subagent") and
            (.agents["gentle-ai-explore"].system | type == "string") and
            (.agents["gentle-ai-explore"].permissions | type == "array") and
            ([.agents[] | (.permissions | type == "array") and all(.permissions[]; has("action") and has("resource") and has("effect"))] | all) and
            (has("agent") | not) and
            (has("permission") | not) and
            ([.agents[] | has("prompt") or has("disable") or has("permission") or has("maxSteps")] | any | not)
          ' ${config} > /dev/null
          touch $out
        '';

      checks.x86_64-linux.ssh-relay-preflight =
        let
          pkgs = nixpkgs.legacyPackages.x86_64-linux;
          unit =
            pkgs.writeText "ssh-relay.service"
              self.nixosConfigurations.rog.config.systemd.units."ssh-relay.service".text;
        in
        pkgs.runCommand "ssh-relay-preflight" { nativeBuildInputs = [ pkgs.python3 ]; } ''
          python3 - ${unit} <<'PY'
          import pathlib
          import re
          import shlex
          import subprocess
          import sys
          import tempfile

          unit = pathlib.Path(sys.argv[1]).read_text()
          commands = [line.removeprefix("ExecStartPre=") for line in unit.splitlines()
                      if line.startswith("ExecStartPre=")]
          assert len(commands) == 4, commands
          assert "stat -c %%a" in unit and "stat -c %%u" in unit
          assert all(not re.search(r"(?<!%)%(?!%)", command) for command in commands)

          with tempfile.TemporaryDirectory(dir=".") as directory:
              parent = pathlib.Path(directory).resolve()
              policy = parent / "restrictions.yaml"
              policy.write_text("synthetic test policy\n")
              policy.chmod(0o600)
              commands = [shlex.split(command.replace("%%", "%").replace("$$", "$"))
                          for command in commands]
              for command in commands:
                  command[-1] = str(policy)

              def accepted():
                  return all(subprocess.run(command, stdout=subprocess.DEVNULL,
                                            stderr=subprocess.DEVNULL).returncode == 0
                             for command in commands)

              # Execute the rendered guards after documented systemd literal escapes,
              # without starting a service or reading any deployed policy.
              for mode in (0o700, 0o750, 0o755):
                  parent.chmod(mode)
                  assert accepted(), oct(mode)
              for mode in (0o720, 0o775, 0o757, 0o777):
                  parent.chmod(mode)
                  assert not accepted(), oct(mode)
              parent.chmod(0o755)
              for mode in (0o400, 0o640, 0o644, 0o666):
                  policy.chmod(mode)
                  assert not accepted(), oct(mode)
              policy.chmod(0o600)
              target = parent / "target.yaml"
              policy.rename(target)
              policy.symlink_to(target)
              assert not accepted(), "symlink policy"
              policy.unlink()
              assert not accepted(), "missing policy"
          PY
          touch $out
        '';

      nixosConfigurations = {
        rog = mkNixosHost { hostname = "rog"; };
        thinkcentre = mkNixosHost { hostname = "thinkcentre"; };
        t14 = mkNixosHost {
          hostname = "t14";
          extraModules = [
            inputs.omarchy-nix.nixosModules.default
            inputs.nixos-hardware.nixosModules.lenovo-thinkpad-t14-amd-gen4
          ];
        };
      };

      darwinConfigurations = {
        macm5 = mkDarwinHost {
          configName = "macm5";
          system = "aarch64-darwin";
          primaryUser = "juan";
          githubUser = "jcuzmar";
        };
      };

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
          macm5 = baseHomeConfig {
            hostname = "macm5";
            system = "aarch64-darwin";
            username = "juan";
            githubUser = "jcuzmar";
            extraModules = [
              ./darwin/home
              {
                home.opencode.activeProviderName = "work-copilot-anthropic";
              }
            ];
          };
        };

      formatter.x86_64-linux = nixpkgs.legacyPackages.x86_64-linux.nixfmt-tree;
      formatter.x86_64-darwin = nixpkgs.legacyPackages.x86_64-darwin.nixfmt-tree;
      formatter.aarch64-darwin = nixpkgs.legacyPackages.aarch64-darwin.nixfmt-tree;

      devShells.x86_64-linux.default = nixpkgs.legacyPackages.x86_64-linux.mkShell {
        packages = with nixpkgs.legacyPackages.x86_64-linux; [ go ];
      };
      devShells.x86_64-darwin.default = nixpkgs.legacyPackages.x86_64-darwin.mkShell {
        packages = with nixpkgs.legacyPackages.x86_64-darwin; [ go ];
      };
    };
}
