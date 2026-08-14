# Browsers profile
# Web browsers available on the system.
#
# Note: chromium and brave are now ungated. t14 evaluates them from
# BOTH nixos-hosts and omarchy-nix; the Nix store deduplicates the
# derivations, so there is no runtime cost. t14 sets
# `omarchy.browser = "brave"` so brave is the active one;
# `google-chrome` is available everywhere.
#
# microsoft-edge is NOT shared here anymore: each host adds it
# explicitly. rog/thinkcentre use the plain package; t14 wraps it to
# XWayland (see hosts/t14/default.nix) to avoid Wayland-native
# flicker/EGL glitches on Hyprland.
{ pkgs }:
with pkgs;
[
  google-chrome
  chromium
  brave
]
