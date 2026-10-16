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
