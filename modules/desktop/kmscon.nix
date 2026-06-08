{ pkgs, lib, ... }:

let
  hexToRgb =
    hex:
    let
      r = lib.fromHexString (builtins.substring 0 2 hex);
      g = lib.fromHexString (builtins.substring 2 2 hex);
      b = lib.fromHexString (builtins.substring 4 2 hex);
    in
    "${toString r},${toString g},${toString b}";

  p = {
    black = "000000";
    red = "cc0403";
    green = "19cb00";
    yellow = "cecb00";
    blue = "0d73cc";
    magenta = "cb1ed1";
    cyan = "0dcdcd";
    white = "dddddd";
    darkGrey = "8a8a8a";
    brightRed = "f2201f";
    brightGreen = "23fd00";
    brightYellow = "fffd00";
    brightBlue = "1a8fff";
    brightMagenta = "fd28ff";
    brightCyan = "14ffff";
    brightWhite = "ffffff";
  };
in

{
  services.kmscon = {
    enable = true;
    hwRender = false;
    useXkbConfig = true;
    fonts = [
      {
        name = "CaskaydiaCove Nerd Font Mono";
        package = pkgs.nerd-fonts.caskaydia-cove;
      }
    ];
    extraConfig = ''
      palette=custom
      palette-background=${hexToRgb p.black}
      palette-foreground=${hexToRgb p.white}
      palette-black=${hexToRgb p.black}
      palette-red=${hexToRgb p.red}
      palette-green=${hexToRgb p.green}
      palette-yellow=${hexToRgb p.yellow}
      palette-blue=${hexToRgb p.blue}
      palette-magenta=${hexToRgb p.magenta}
      palette-cyan=${hexToRgb p.cyan}
      palette-light-grey=${hexToRgb p.white}
      palette-dark-grey=${hexToRgb p.darkGrey}
      palette-light-red=${hexToRgb p.brightRed}
      palette-light-green=${hexToRgb p.brightGreen}
      palette-light-yellow=${hexToRgb p.brightYellow}
      palette-light-blue=${hexToRgb p.brightBlue}
      palette-light-magenta=${hexToRgb p.brightMagenta}
      palette-light-cyan=${hexToRgb p.brightCyan}
      palette-white=${hexToRgb p.brightWhite}
    '';
  };
}
