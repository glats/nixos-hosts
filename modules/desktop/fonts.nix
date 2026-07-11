{ config
, pkgs
, lib
, ...
}:
let
  fontconfigXML = ''
    <?xml version="1.0"?>
    <!DOCTYPE fontconfig SYSTEM "urn:fontconfig:fonts.dtd">
    <fontconfig>
      <!-- Redirect known font names to generic families -->
      <match target="pattern">
        <test name="family" qual="any"><string>Roboto</string></test>
        <edit name="family" mode="assign" binding="same"><string>sans-serif</string></edit>
      </match>
      <match target="pattern">
        <test name="family" qual="any"><string>Helvetica</string></test>
        <edit name="family" mode="assign" binding="same"><string>sans-serif</string></edit>
      </match>
      <match target="pattern">
        <test name="family" qual="any"><string>Arial</string></test>
        <edit name="family" mode="assign" binding="same"><string>sans</string></edit>
      </match>
      <match target="pattern">
        <test name="family" qual="any"><string>Verdana</string></test>
        <edit name="family" mode="assign" binding="same"><string>sans-serif</string></edit>
      </match>
      <match target="pattern">
        <test name="family" qual="any"><string>Tahoma</string></test>
        <edit name="family" mode="assign" binding="same"><string>sans-serif</string></edit>
      </match>
      <match target="pattern">
        <test name="family" qual="any"><string>Times</string></test>
        <edit name="family" mode="assign" binding="same"><string>serif</string></edit>
      </match>
      <match target="pattern">
        <test name="family" qual="any"><string>Courier</string></test>
        <edit name="family" mode="assign" binding="same"><string>monospace</string></edit>
      </match>
      <match target="pattern">
        <test name="family" qual="any"><string>Terminal</string></test>
        <edit name="family" mode="assign" binding="same"><string>monospace</string></edit>
      </match>

      <!-- Font family preferences -->
      <alias binding="strong">
        <family>sans-serif</family>
        <prefer>
          <family>Source Sans 3</family>
          <family>Noto Sans</family>
          <family>JoyPixels</family>
        </prefer>
        <default><family>Noto Sans</family></default>
      </alias>

      <alias binding="strong">
        <family>sans</family>
        <prefer>
          <family>Source Sans 3</family>
          <family>Noto Sans</family>
          <family>JoyPixels</family>
        </prefer>
        <default><family>Noto Sans</family></default>
      </alias>

      <alias binding="strong">
        <family>serif</family>
        <prefer>
          <family>Noto Serif</family>
          <family>JoyPixels</family>
        </prefer>
        <default><family>Noto Serif</family></default>
      </alias>

      <alias binding="strong">
        <family>monospace</family>
        <prefer>
          <family>CaskaydiaCove Nerd Font</family>
          <family>Symbols Nerd Font</family>
          <family>Symbola</family>
        </prefer>
      </alias>
    </fontconfig>
  '';
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
