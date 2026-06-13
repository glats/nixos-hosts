# T14 Hyprland keybindings — non-visual extensions on top of omarchy.
#
# Omarchy owns the full binding surface.  This module adds only
# t14-specific scripts that omarchy does not provide.
{ ... }:

{
  wayland.windowManager.hyprland.extraConfig = ''
    # T14: Window switcher (walker-based, uses omarchy's walker menu backend)
    # `bindd` requires 5 positional fields: mod, key, description,
    # dispatcher, arg. The previous form had only 4 (missing the
    # description), so hyprland silently dropped the binding. Add a
    # description between key and dispatcher.
    bindd = SUPER, Q, Window switcher, exec, window-switcher.sh
  '';
}
