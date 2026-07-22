{ pkgs, lib, ... }:

let
  palette = import ../../../shared/palette.nix;
  colors = import ../../../lib/colors.nix { inherit lib; };
  p = palette.palette;
in

{
  fonts.packages = [ pkgs.nerd-fonts.caskaydia-cove ];

  services.kmscon = {
    enable = true;
    config.hwaccel = false;
    useXkbConfig = true;
    config = {
      font-name = "CaskaydiaCove Nerd Font Mono";
      palette = "custom";
      palette-background = colors.hexToRgb p.base00;
      palette-foreground = colors.hexToRgb p.base05;
      palette-black = colors.hexToRgb p.base00;
      palette-red = colors.hexToRgb p.base08;
      palette-green = colors.hexToRgb p.base0B;
      palette-yellow = colors.hexToRgb p.base0A;
      palette-blue = colors.hexToRgb p.base0D;
      palette-magenta = colors.hexToRgb p.base0E;
      palette-cyan = colors.hexToRgb p.base0C;
      palette-light-grey = colors.hexToRgb p.base05;
      palette-dark-grey = colors.hexToRgb p.base03;
      palette-light-red = colors.hexToRgb p.base09;
      palette-light-green = colors.hexToRgb p.brightGreen;
      palette-light-yellow = colors.hexToRgb p.brightYellow;
      palette-light-blue = colors.hexToRgb p.brightBlue;
      palette-light-magenta = colors.hexToRgb p.brightMagenta;
      palette-light-cyan = colors.hexToRgb p.brightCyan;
      palette-white = colors.hexToRgb p.base07;
    };
  };
}
