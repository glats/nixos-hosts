# Browsers profile
# Web browsers available on the system.
#
# `chromium` and `brave` are gated with `lib.mkIf (cfg != "gnome")`
# because omarchy-nix already provides them on t14 (suite = "gnome").
# t14 sets `omarchy.browser = "brave"` so brave is the active one;
# `google-chrome` and `microsoft-edge` are rog/thinkcentre-only.
{ pkgs
, config
, lib
, ...
}:
let
  cfg = config.my.desktop.suite;
  nonGnome = p: lib.mkIf (cfg != "gnome") p;
in
with pkgs;
[
  google-chrome
  microsoft-edge
  (nonGnome chromium)
  (nonGnome brave)
]
