{ config
, pkgs
, lib
, ...
}:

let
  # Font families to reject (rejected in <rejectfont> blocks)
  rejectedFonts = [
    "Liberation Sans"
    "Liberation Serif"
    "Liberation Mono"
    "DejaVu Sans"
    "DejaVu Serif"
    "DejaVu Sans Mono"
    "Arimo"
    "Tinos"
    "Cousine"
  ];

  # Font names that should be remapped to a generic family
  sansSerifAliases = [
    "Arial"
    "Helvetica"
    "Helvetica Neue"
    "Verdana"
    "Tahoma"
    "Geneva"
    "Cantarell"
  ];

  serifAliases = [
    "Times New Roman"
    "Times"
  ];

  monospaceAliases = [
    "Courier New"
    "Courier"
    "Terminal"
  ];

  # Force these names to resolve to the monospace font
  monoForceNames = [
    "monospace"
    "mono"
  ];
  monoFont = "CaskaydiaCove Nerd Font";

  # Strong aliases (preference order) per family
  familyPrefs = {
    "sans-serif" = [
      "Source Sans 3"
      "Noto Sans"
    ];
    sans = [
      "Source Sans 3"
      "Noto Sans"
    ];
    serif = [
      "Source Sans 3"
      "Noto Serif"
    ];
    monospace = [
      monoFont
      "Noto Sans Mono"
    ];
  };

  # Emoji fallbacks (weak accept aliases)
  emojiFonts = [
    "JoyPixels"
    "Noto Color Emoji"
  ];
  emojiFamilies = [
    "sans-serif"
    "sans"
    "serif"
    "monospace"
  ];

  # XML generators
  mkRejectPattern = font: ''
    <pattern>
      <patelt name="family">
        <string>${font}</string>
      </patelt>
    </pattern>
  '';

  mkMatchRedirect = from: to: ''
    <match target="pattern">
      <test name="family" qual="any">
        <string>${from}</string>
      </test>
      <edit name="family" mode="assign" binding="same">
        <string>${to}</string>
      </edit>
    </match>
  '';

  mkForceMatch = from: to: ''
    <match target="pattern">
      <test name="family" compare="eq">
        <string>${from}</string>
      </test>
      <edit name="family" mode="assign" binding="same">
        <string>${to}</string>
      </edit>
    </match>
  '';

  mkStrongAlias = family: prefers: ''
    <alias binding="strong">
      <family>${family}</family>
      <prefer>
        ${lib.concatMapStringsSep "\n          " (p: "<family>${p}</family>") prefers}
      </prefer>
    </alias>
  '';

  mkWeakAlias = family: accepts: ''
    <alias binding="weak">
      <family>${family}</family>
      <accept>
        ${lib.concatMapStringsSep "\n          " (a: "<family>${a}</family>") accepts}
      </accept>
    </alias>
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
      localConf = ''
        <?xml version="1.0"?>
        <!DOCTYPE fontconfig SYSTEM "urn:fontconfig:fonts.dtd">
        <fontconfig>
          <!-- Reject fonts we don't want to use -->
          <selectfont>
            <rejectfont>
              ${lib.concatMapStringsSep "\n              " mkRejectPattern rejectedFonts}
            </rejectfont>
          </selectfont>

          <!-- Redirect common font names to our preferred families -->
          ${lib.concatMapStringsSep "\n          " (f: mkMatchRedirect f "sans-serif") sansSerifAliases}
          ${lib.concatMapStringsSep "\n          " (f: mkMatchRedirect f "serif") serifAliases}
          ${lib.concatMapStringsSep "\n          " (f: mkMatchRedirect f "monospace") monospaceAliases}

          <!-- Force monospace family -->
          ${lib.concatMapStringsSep "\n          " (f: mkForceMatch f monoFont) monoForceNames}

          <!-- Define font family preferences -->
          ${lib.concatMapStringsSep "\n          " (entry: mkStrongAlias entry.family entry.prefer) (
            lib.mapAttrsToList (family: prefer: { inherit family prefer; }) familyPrefs
          )}

          <!-- Emoji fallbacks -->
          ${lib.concatMapStringsSep "\n          " (f: mkWeakAlias f emojiFonts) emojiFamilies}
        </fontconfig>
      '';
      defaultFonts = {
        serif = [
          "Source Sans 3"
          "Noto Serif"
        ];
        sansSerif = [
          "Source Sans 3"
          "Noto Sans"
        ];
        monospace = [
          "CaskaydiaCove Nerd Font"
          "Noto Sans Mono"
        ];
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
      joypixels
      noto-fonts
      noto-fonts-cjk-sans
    ];
  };

  # Font audit note (T3-007): the Home Manager module brought in by
  # omarchy-nix (modules/home-manager/fonts.nix) installs its own copy
  # of noto-fonts, noto-fonts-color-emoji, nerd-fonts.caskaydia-mono,
  # and nerd-fonts.jetbrains-mono at the user level.  This NixOS module
  # intentionally keeps the system-level font packages separate so
  # that the console / kmscon / early-boot text rendering can resolve
  # fonts without depending on the user session.
  #
  # The two scopes are:
  #   * NixOS (this file): console, kmscon, getty, display managers.
  #   * HM (omarchy):      GTK apps, ghostty, waybar, hyprland text.
  # No deduplication is needed because they serve different scopes.
}
