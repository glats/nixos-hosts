{ pkgs, ... }:

let
  hexToRgb = hex:
    let
      n = c: {
        "0" = 0;
        "1" = 1;
        "2" = 2;
        "3" = 3;
        "4" = 4;
        "5" = 5;
        "6" = 6;
        "7" = 7;
        "8" = 8;
        "9" = 9;
        "a" = 10;
        "b" = 11;
        "c" = 12;
        "d" = 13;
        "e" = 14;
        "f" = 15;
      }.${c};
      byte = s: n (builtins.substring 0 1 s) * 16 + n (builtins.substring 1 1 s);
      r = byte (builtins.substring 0 2 hex);
      g = byte (builtins.substring 2 2 hex);
      b = byte (builtins.substring 4 2 hex);
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
