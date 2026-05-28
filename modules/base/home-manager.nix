{ config, lib, pkgs, inputs, ... }:

let
  hostName = config.networking.hostName;

  sharedImports = [
    ../home/base.nix
    ../home/shell.nix
    ../home/btop.nix
    ../home/tmux.nix
    ../home/neovim.nix
    ../home/git.nix
    ../home/gh.nix
    ../home/opencode.nix
    ../home/opencode-profile.nix
    ../home/openfang.nix
    ../home/chrome-apps.nix
    ../home/ssh.nix
    ../home/sops.nix
    inputs.sops-nix.homeManagerModules.sops
  ];

  sharedDesktopImports = [
    ../home/mate.nix
    ../home/rofi.nix
    ../home/ghostty.nix
    ../home/kitty.nix
  ];
in
{
  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    extraSpecialArgs = {
      inherit inputs;
      inherit hostName;
      conkyConfig = config.conky-config;
      # Force rebuild: 2026-05-03
    };
    users.glats = {
      imports = sharedImports
        ++ lib.optionals (hostName != "t14") [
        ../home/theme.nix
      ]
        ++ lib.optionals (hostName != "t14") sharedDesktopImports
        ++ lib.optionals (hostName == "t14") [
        inputs.omarchy-nix.homeManagerModules.default
      ]
        ++ lib.optionals (hostName == "rog") [
        ../home/conky-rog.nix
      ] ++ lib.optionals (hostName == "thinkcentre") [
        ../home/conky-thinkcentre.nix
      ];
    };
  };
}
