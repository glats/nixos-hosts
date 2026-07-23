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
    # No env overrides: WLR_RENDERER_ALLOW_SOFTWARE,0 was removed — it is
    # obsolete on Hyprland 0.54+ (the wlroots render-backend selection hook
    # it addressed no longer exists), and the AMD Phoenix iGPU never selects
    # software rendering.  No replacement needed.

    # T14: no inner gaps, tight outer gaps.  Overrides the omarchy
    # default gaps_in=5 / gaps_out=10 with the user's preferred
    # gaps_in=0 / gaps_out=2.5.  mkForce required because upstream
    # also sets these keys at higher priority.
    general = {
      gaps_in = lib.mkForce 0;
      gaps_out = lib.mkForce 2.5;
    };

    # T14: override omarchy decoration — disable blur/shadow so no
    # window has transparency or glass effects.
    decoration = lib.mkForce {
      rounding = 0;
      shadow.enabled = false;
      blur.enabled = false;
    };

    # T14: disable Hyprland's automatic workspace tracking so the
    # initial workspace does not follow the focused window when
    # restoring a session.  Matches the user's source looknfeel.conf
    # and prevents focus jumping when reopening apps.
    misc.initial_workspace_tracking = false;
  };

  # xdg-desktop-portal-gtk file picker dialogs render with a transparent
  # gap under XWayland: GTK reports window geometry including CSD shadow
  # area, but the actual visible content is smaller.  Hyprland draws its
  # border around the full reported size (unfixable on Hyprland's side
  # for XWayland — see hyprwm/Hyprland#5192).  Remove the compositor
  # border on these dialogs; GTK provides its own CSD decorations.
  wayland.windowManager.hyprland.extraConfig = lib.mkAfter ''
    windowrule = bordersize 0, class:^(xdg-desktop-portal-gtk)$
  '';
}
