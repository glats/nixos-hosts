{ config
, pkgs
, lib
, ...
}:
let
  fontconfigXML = builtins.readFile ../../../shared/fontconfig/family-map.xml;
in
{
  fonts = {
    fontconfig = {
      enable = true;
      antialias = true;
      hinting = {
        enable = true;
        autohint = false;
        style = "slight";
      };
      subpixel = {
        rgba = "rgb";
        lcdfilter = "default";
      };
      defaultFonts = {
        serif = [ "Noto Serif" ];
        sansSerif = [ "Source Sans 3" ];
        monospace = [ "CaskaydiaCove Nerd Font" ];
        emoji = [
          "JoyPixels"
          "Noto Color Emoji"
        ];
      };
    };
    fontDir.enable = true;
    packages = with pkgs; [
      source-sans
      nerd-fonts.caskaydia-cove
      nerd-fonts.symbols-only
      symbola
      joypixels
      noto-fonts
      noto-fonts-cjk-sans
    ];
  };

  fonts.fontconfig.confPackages = [
    (pkgs.writeTextFile {
      name = "fontconfig-51-custom";
      destination = "/etc/fonts/conf.d/51-nixos-custom.conf";
      text = fontconfigXML;
    })
  ];
}
