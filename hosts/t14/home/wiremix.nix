# T14 wiremix config.
#
# Minimal wiremix configuration ported from the external drive's
# `~/.config/wiremix/wiremix.toml`.  Omarchy has no wiremix module,
# so this is a simple xdg.configFile drop-in.  The config sets a
# custom default-device glyph.
{ ... }:

{
  xdg.configFile."wiremix/config.toml".text = ''
    # overwrites default wiremix configuration
    # defaults: https://github.com/tsowell/wiremix/blob/main/wiremix.toml

    [char_sets.default]
    default_device = "⮞"
  '';
}
