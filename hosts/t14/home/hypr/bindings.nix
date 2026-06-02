# T14 Hyprland keybindings — non-visual extensions on top of omarchy.
#
# Omarchy owns the full binding surface.  This module adds only
# t14-specific scripts that omarchy does not provide.
{ ... }:

{
  wayland.windowManager.hyprland.extraConfig = ''
    # T14: Window switcher (walker-based, uses omarchy's walker menu backend)
    bindd = SUPER, Q, exec, window-switcher.sh
  '';
}
