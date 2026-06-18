# T14 ghostty overlay.
#
# Imports the shared `home-linux/ghostty.nix` module — the single source
# of truth for ghostty config across every Linux host.  The shared
# module wraps `programs.ghostty.settings` in `lib.mkForce` so the
# entire attrset replaces whatever omarchy-nix contributed via
# `inputs.omarchy-nix.homeManagerModules.default`.  t14 therefore
# gets byte-identical ghostty config to rog / thinkcentre.
#
# This file intentionally defines no overrides — the t14-specific
# `background-opacity = 0.9` and `mouse-scroll-multiplier = 0.95`
# tweaks that used to live here were dropped to keep t14 in sync
# with the rog set.  Touchpad scroll speed is now controlled via
# Hyprland (`hosts/t14/home/hypr/input.nix`, `scroll_touchpad 0.2`).
{
  imports = [ ../../../home-linux/ghostty.nix ];
}
