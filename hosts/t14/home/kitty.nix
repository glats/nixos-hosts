# T14 kitty overlay.
#
# Imports the shared `home-linux/kitty.nix` module (which sets the
# colorScheme palette) and applies t14-specific font settings.  We
# use `lib.mkForce` on the color keys so the shared module's
# colorScheme palette wins over omarchy's `include` directive.
#
# T14-specific overrides:
#   * font.name = "CaskaydiaCove Nerd Font"
#   * font.size = 11
{ config, lib, ... }:

{
  imports = [ ../../../home-linux/kitty.nix ];

  programs.kitty = {
    font = {
      name = "CaskaydiaCove Nerd Font";
      size = 11;
    };

    # Force the shared module's colorScheme palette over omarchy's
    # `include` directive.  Same source-of-truth as
    # `home-linux/kitty.nix` — the values are re-derived from
    # `config.colorScheme.palette` so this stays in sync with the
    # shared module.
    settings = {
      background = lib.mkForce "#${config.colorScheme.palette.base00}";
      foreground = lib.mkForce "#${config.colorScheme.palette.base05}";

      cursor = lib.mkForce "#${config.colorScheme.palette.base05}";
      selection_background = lib.mkForce "#${config.colorScheme.palette.base02}";
      selection_foreground = lib.mkForce "#${config.colorScheme.palette.base05}";

      # Normal colors (0-7)
      color0 = lib.mkForce "#${config.colorScheme.palette.base00}";
      color1 = lib.mkForce "#${config.colorScheme.palette.base08}";
      color2 = lib.mkForce "#${config.colorScheme.palette.base0B}";
      color3 = lib.mkForce "#${config.colorScheme.palette.base0A}";
      color4 = lib.mkForce "#${config.colorScheme.palette.base0D}";
      color5 = lib.mkForce "#${config.colorScheme.palette.base0E}";
      color6 = lib.mkForce "#${config.colorScheme.palette.base0C}";
      color7 = lib.mkForce "#${config.colorScheme.palette.base05}";

      # Bright colors (8-15).  See the matching comment in
      # `home-linux/kitty.nix` for the `or` fallback rationale:
      # t14 uses tokyo-night which lacks the project's bright* attrs.
      color8 = lib.mkForce "#${config.colorScheme.palette.base03}";
      color9 = lib.mkForce "#${config.colorScheme.palette.base09}";
      color10 = lib.mkForce "#${
        config.colorScheme.palette.brightGreen or config.colorScheme.palette.base0B
      }";
      color11 = lib.mkForce "#${
        config.colorScheme.palette.brightYellow or config.colorScheme.palette.base0A
      }";
      color12 = lib.mkForce "#${
        config.colorScheme.palette.brightBlue or config.colorScheme.palette.base0D
      }";
      color13 = lib.mkForce "#${
        config.colorScheme.palette.brightMagenta or config.colorScheme.palette.base0E
      }";
      color14 = lib.mkForce "#${
        config.colorScheme.palette.brightCyan or config.colorScheme.palette.base0C
      }";
      color15 = lib.mkForce "#${config.colorScheme.palette.base07}";
    };
  };
}
