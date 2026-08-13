# T14 Hyprland — window group (tab) bindings.
#
# Window grouping in Hyprland = i3-style tabbed containers:
#   togglegroup        — create/dissolve a group with the active window
#   changegroupactive  — switch active tab (f/b or index)
#   moveintogroup      — merge active window into the group in a direction
#   moveoutofgroup     — remove active window from its group
#   movegroupwindow    — swap active tab with prev/next INSIDE its group
#
# omarchy-nix ships the first four (SUPER G, SUPER ALT + G/arrows/TAB,
# SUPER CTRL + LEFT/RIGHT) but not movegroupwindow.  These two bindings
# are deliberately kept LOCAL to this repo instead of being contributed
# upstream: omarchy-nix is a fork tracking mrosseel/omarchy-nix and any
# non-upstream binding increases sync friction on every merge.
#
# bindd (not bind) is used so the descriptions show up in the SUPER+K
# keybinding picker, matching omarchy's own entries.  The picker script
# (~/.local/share/omarchy/bin/omarchy-show-keybindings) greps this file.
#
# See docs/t14-hyprland-groups.md for the full workflow.
{ ... }:

{
  wayland.windowManager.hyprland.extraConfig = ''
    # Reorder tabs within a group (swaps active with prev/next)
    bindd = SUPER CTRL SHIFT, LEFT, Move group tab backward, movegroupwindow, b
    bindd = SUPER CTRL SHIFT, RIGHT, Move group tab forward, movegroupwindow, f
  '';
}
