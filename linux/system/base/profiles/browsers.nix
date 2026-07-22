# Browsers profile
# Web browsers available on the system.
#
# Note: chromium and brave are now ungated. t14 evaluates them from
# BOTH nixos-hosts and omarchy-nix; the Nix store deduplicates the
# derivations, so there is no runtime cost. t14 sets
# `omarchy.browser = "brave"` so brave is the active one;
# `google-chrome` and `microsoft-edge` are available everywhere but
# rog/thinkcentre are the primary users.
{ pkgs }:
with pkgs;
[
  google-chrome
  microsoft-edge
  chromium
  brave
]
