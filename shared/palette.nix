# Shared color palette - pure attrset, no GTK/QT/dconf
# Used by both Linux (home-linux/theme.nix) and Darwin (home-darwin/theme.nix)
{
  slug = "glats";
  name = "Glats";
  author = "Custom";
  palette = {
    # Monotonic gray gradient (dark → light)
    base00 = "000000"; # 0%  - background
    base01 = "1a1a1a"; # 10% - lighter background
    base02 = "505050"; # 31% - selection background
    base03 = "767676"; # 46% - comments
    base04 = "a0a0a0"; # 63% - dark foreground
    base05 = "e0e0e0"; # 88% - default foreground
    base06 = "f0f0f0"; # 94% - light foreground
    base07 = "ffffff"; # 100% - light background

    # Accent colors (bright/vivid variants)
    base08 = "f2201f"; # red
    base09 = "ff8800"; # orange
    base0A = "fffd00"; # yellow
    base0B = "23fd00"; # green
    base0C = "14ffff"; # cyan
    base0D = "1a8fff"; # blue
    base0E = "fd28ff"; # magenta
    base0F = "ff6600"; # deprecated

    # Legacy bright variants (unused by base16 standard but preserved)
    brightGreen = "23fd00";
    brightYellow = "fffd00";
    brightBlue = "1a8fff";
    brightMagenta = "fd28ff";
    brightCyan = "14ffff";
  };
}
