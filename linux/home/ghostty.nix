{
  config,
  lib,
  ...
}:
let
  cfg = config.home.ghostty;

  xrdpSettings = {
    scrollback-limit = 10000000;
    background-opacity = 1;
    background-blur = false;
    cursor-style-blink = false;
    link-url = false;
  };

  ghostty = import ../../shared/ghostty.nix {
    colorScheme = config.colorScheme;
    extraSettings = lib.optionalAttrs cfg.xrdp-optimized xrdpSettings;
  };
in
{
  options.home.ghostty.xrdp-optimized = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = ''
      Whether to apply the low footprint Ghostty profile used on hosts that
      serve XRDP sessions.

      The profile bounds the scrollback buffer to 10 MB. Ghostty 1.0 and later
      measure `scrollback-limit` in bytes per terminal surface, not in lines,
      so the shared value of 4294967295 authorises 4 GiB of scrollback per
      surface. It also makes the window fully opaque so the compositor skips
      per frame alpha blending, and it disables cursor blinking and URL hover
      matching so an idle terminal does not repaint continuously.

      Enable it only on hosts that serve XRDP sessions. The local desktop
      hosts keep the translucent shared look.
    '';
  };

  config.programs.ghostty = {
    enable = true;
    settings = lib.mkForce ghostty.settings;
    themes = lib.mkForce ghostty.theme;
  };
}
