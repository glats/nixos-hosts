{ ... }:

{
  wayland.windowManager.hyprland.extraConfig = ''
    # Reorder tabs within a group (swaps active with prev/next)
    bindd = SUPER CTRL SHIFT, LEFT, Move group tab backward, movegroupwindow, b
    bindd = SUPER CTRL SHIFT, RIGHT, Move group tab forward, movegroupwindow, f
  '';
}
