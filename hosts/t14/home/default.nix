# T14 Home Manager module list.
#
# Same list-function shape as rog/thinkcentre: shared base filtered for
# omarchy compatibility, then t14-specific overlays appended.
#
# Excluded from shared base:
#   - theme.nix       — omarchy owns GTK/Qt/colorScheme via omarchy.theme
#   - fontconfig.nix  — omarchy-nix HM fonts module handles font config
#   - alacritty.nix   — omarchy provides its own alacritty profile
#   - gpg.nix         — not used on t14 (no GNOME keyring integration)
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
  ({ home.opencode.activeProviderName = "openai-full"; })
  inputs.hyprdynamicmonitors.homeManagerModules.default
]
