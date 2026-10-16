{ inputs }:

let
  base = import ../../../linux/home/shared-modules.nix { inherit inputs; };
  excluded = [
    ../../../linux/home/theme.nix
    ../../../linux/home/fontconfig.nix
    ../../../linux/home/alacritty.nix
    ../../../linux/home/gpg.nix
  ];
in
builtins.filter (m: !builtins.elem m excluded) base
++ [
  ./omarchy.nix
  ../../../linux/home/remote-desktop.nix
  ({ home.opencode.activeProviderName = "openai-anthropic-opencode"; })
  inputs.hyprdynamicmonitors.homeManagerModules.default
]
