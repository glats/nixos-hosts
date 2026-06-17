# T14 kitty overlay.
#
# Imports the shared `home-linux/kitty.nix` module (which sets the
# full 22-color palette derived from `config.colorScheme.palette`)
# and applies t14-specific font settings.  The shared module is the
# single source of truth for kitty's colorScheme now that omarchy-nix
# drives `colorScheme` from `omarchy.theme = "glats"`.
#
# T14-specific overrides:
#   * font.name = "CaskaydiaCove Nerd Font"
#   * font.size = 11
{ ... }:

{
  imports = [ ../../../home-linux/kitty.nix ];

  programs.kitty.font = {
    name = "CaskaydiaCove Nerd Font";
    size = 11;
  };
}
