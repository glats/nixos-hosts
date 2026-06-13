# T14 Hyprland look and feel — non-theme visual overrides.
#
# Visual theming (colours, decoration style, border radius, fonts) is
# owned entirely by omarchy's theme runtime and is out of scope here.
# This module holds only structural/hardware-specific rendering tweaks.
#
# Override strategy: omarchy's upstream hyprland/looknfeel.nix sets
# `wayland.windowManager.hyprland.settings.general.gaps_in = 5` and
# `gaps_out = 10` as plain (priority 100) values.  T14 uses
# `lib.mkForce` (priority 50) to override these with the user's
# preferred gaps_in=0 and gaps_out=2.5.
#
# The `misc.initial_workspace_tracking = false` is not set by upstream,
# so no mkForce is needed there — the attrset merge just adds it.
{ lib, ... }:

{
  wayland.windowManager.hyprland.settings = {
    # T14: AMD Phoenix 3 APU — enable basic anti-aliasing
    # for crisp text without performance overhead.
    env = [
      "WLR_RENDERER_ALLOW_SOFTWARE,0"
    ];

    # T14: no inner gaps, tight outer gaps.  Overrides the omarchy
    # default gaps_in=5 / gaps_out=10 with the user's preferred
    # gaps_in=0 / gaps_out=2.5.  mkForce required because upstream
    # also sets these keys at higher priority.
    general = {
      gaps_in = lib.mkForce 0;
      gaps_out = lib.mkForce 2.5;
    };

    # T14: disable Hyprland's automatic workspace tracking so the
    # initial workspace does not follow the focused window when
    # restoring a session.  Matches the user's source looknfeel.conf
    # and prevents focus jumping when reopening apps.
    misc.initial_workspace_tracking = false;
  };
}
