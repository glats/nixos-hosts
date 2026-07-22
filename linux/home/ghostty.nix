# Linux Ghostty terminal configuration.
# Imports shared ghostty settings + palette. Uses lib.mkForce to override
# omarchy-nix contributions on t14 (settings and themes).
{ config, lib, ... }:
let
  ghostty = import ../../shared/ghostty.nix {
    colorScheme = config.colorScheme;
  };
in
{
  programs.ghostty = {
    enable = true;
    settings = lib.mkForce ghostty.settings;
    themes = lib.mkForce ghostty.theme;
  };
}
