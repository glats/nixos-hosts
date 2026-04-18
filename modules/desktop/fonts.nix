{ config, pkgs, ... }:

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
      localConf = ''
        <?xml version="1.0"?>
        <!DOCTYPE fontconfig SYSTEM "urn:fontconfig:fonts.dtd">
        <fontconfig>
          <!-- Reject fonts we don't want to use -->
          <selectfont>
            <rejectfont>
              <!-- Reject Liberation fonts -->
              <pattern>
                <patelt name="family">
                  <string>Liberation Sans</string>
                </patelt>
              </pattern>
              <pattern>
                <patelt name="family">
                  <string>Liberation Serif</string>
                </patelt>
              </pattern>
              <pattern>
                <patelt name="family">
                  <string>Liberation Mono</string>
                </patelt>
              </pattern>
              <!-- Reject DejaVu fonts -->
              <pattern>
                <patelt name="family">
                  <string>DejaVu Sans</string>
                </patelt>
              </pattern>
              <pattern>
                <patelt name="family">
                  <string>DejaVu Serif</string>
                </patelt>
              </pattern>
              <pattern>
                <patelt name="family">
                  <string>DejaVu Sans Mono</string>
                </patelt>
              </pattern>
              <!-- Reject other common fallback fonts -->
              <pattern>
                <patelt name="family">
                  <string>Arimo</string>
                </patelt>
              </pattern>
              <pattern>
                <patelt name="family">
                  <string>Tinos</string>
                </patelt>
              </pattern>
              <pattern>
                <patelt name="family">
                  <string>Cousine</string>
                </patelt>
              </pattern>
            </rejectfont>
          </selectfont>

          <!-- Redirect common font names to our preferred families -->
          <match target="pattern">
            <test name="family" qual="any">
              <string>Arial</string>
            </test>
            <edit name="family" mode="assign" binding="same">
              <string>sans-serif</string>
            </edit>
          </match>
          <match target="pattern">
            <test name="family" qual="any">
              <string>Helvetica</string>
            </test>
            <edit name="family" mode="assign" binding="same">
              <string>sans-serif</string>
            </edit>
          </match>
          <match target="pattern">
            <test name="family" qual="any">
              <string>Helvetica Neue</string>
            </test>
            <edit name="family" mode="assign" binding="same">
              <string>sans-serif</string>
            </edit>
          </match>
          <match target="pattern">
            <test name="family" qual="any">
              <string>Verdana</string>
            </test>
            <edit name="family" mode="assign" binding="same">
              <string>sans-serif</string>
            </edit>
          </match>
          <match target="pattern">
            <test name="family" qual="any">
              <string>Tahoma</string>
            </test>
            <edit name="family" mode="assign" binding="same">
              <string>sans-serif</string>
            </edit>
          </match>
          <match target="pattern">
            <test name="family" qual="any">
              <string>Geneva</string>
            </test>
            <edit name="family" mode="assign" binding="same">
              <string>sans-serif</string>
            </edit>
          </match>
          <match target="pattern">
            <test name="family" qual="any">
              <string>Cantarell</string>
            </test>
            <edit name="family" mode="assign" binding="same">
              <string>sans-serif</string>
            </edit>
          </match>
          <match target="pattern">
            <test name="family" qual="any">
              <string>Times New Roman</string>
            </test>
            <edit name="family" mode="assign" binding="same">
              <string>serif</string>
            </edit>
          </match>
          <match target="pattern">
            <test name="family" qual="any">
              <string>Times</string>
            </test>
            <edit name="family" mode="assign" binding="same">
              <string>serif</string>
            </edit>
          </match>
          <match target="pattern">
            <test name="family" qual="any">
              <string>Courier New</string>
            </test>
            <edit name="family" mode="assign" binding="same">
              <string>monospace</string>
            </edit>
          </match>
          <match target="pattern">
            <test name="family" qual="any">
              <string>Courier</string>
            </test>
            <edit name="family" mode="assign" binding="same">
              <string>monospace</string>
            </edit>
          </match>
          <match target="pattern">
            <test name="family" qual="any">
              <string>Terminal</string>
            </test>
            <edit name="family" mode="assign" binding="same">
              <string>monospace</string>
            </edit>
          </match>

          <!-- Force monospace family -->
          <match target="pattern">
            <test name="family" compare="eq">
              <string>monospace</string>
            </test>
            <edit name="family" mode="assign" binding="same">
              <string>CaskaydiaCove Nerd Font</string>
            </edit>
          </match>
          <match target="pattern">
            <test name="family" compare="eq">
              <string>mono</string>
            </test>
            <edit name="family" mode="assign" binding="same">
              <string>CaskaydiaCove Nerd Font</string>
            </edit>
          </match>

          <!-- Define font family preferences -->
          <alias binding="strong">
            <family>sans-serif</family>
            <prefer>
              <family>Source Sans 3</family>
              <family>Noto Sans</family>
            </prefer>
          </alias>
          <alias binding="strong">
            <family>sans</family>
            <prefer>
              <family>Source Sans 3</family>
              <family>Noto Sans</family>
            </prefer>
          </alias>
          <alias binding="strong">
            <family>serif</family>
            <prefer>
              <family>Source Sans 3</family>
              <family>Noto Serif</family>
            </prefer>
          </alias>
          <alias binding="strong">
            <family>monospace</family>
            <prefer>
              <family>CaskaydiaCove Nerd Font</family>
              <family>Noto Sans Mono</family>
            </prefer>
          </alias>

          <!-- Emoji fallbacks -->
          <alias binding="weak">
            <family>sans-serif</family>
            <accept>
              <family>JoyPixels</family>
              <family>Noto Color Emoji</family>
            </accept>
          </alias>
          <alias binding="weak">
            <family>sans</family>
            <accept>
              <family>JoyPixels</family>
              <family>Noto Color Emoji</family>
            </accept>
          </alias>
          <alias binding="weak">
            <family>serif</family>
            <accept>
              <family>JoyPixels</family>
              <family>Noto Color Emoji</family>
            </accept>
          </alias>
          <alias binding="weak">
            <family>monospace</family>
            <accept>
              <family>JoyPixels</family>
              <family>Noto Color Emoji</family>
            </accept>
          </alias>
        </fontconfig>
      '';
      defaultFonts = {
        serif = [ "Source Sans 3" "Noto Serif" ];
        sansSerif = [ "Source Sans 3" "Noto Sans" ];
        monospace = [ "CaskaydiaCove Nerd Font" "Noto Sans Mono" ];
        emoji = [ "JoyPixels" "Noto Color Emoji" ];
      };
    };
    fontDir.enable = true;
    packages = with pkgs; [
      source-sans
      nerd-fonts.caskaydia-cove
      joypixels
      noto-fonts
      noto-fonts-cjk-sans
    ];
  };
}
