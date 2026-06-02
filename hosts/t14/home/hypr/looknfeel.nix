# T14 Hyprland look and feel — non-theme visual overrides.
#
# Visual theming (colours, decoration style, border radius, fonts) is
# owned entirely by omarchy's theme runtime and is out of scope here.
# This module holds only structural/hardware-specific rendering tweaks.
{ ... }:

{
  wayland.windowManager.hyprland.settings = {
    # T14: AMD Phoenix 3 APU — enable basic anti-aliasing
    # for crisp text without performance overhead.
    env = [
      "WLR_RENDERER_ALLOW_SOFTWARE,0"
    ];

    # No extra general gaps — workspace gaps are handled by omarchy's
    # looknfeel module which is evaluated before this fragment.
    general = {
      # (empty — omarchy looknfeel.nix owns all general settings)
    };
  };
}
