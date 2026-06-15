# Theme file generators for the "glats" omarchy theme.
#
# Every color is derived from `config.colorScheme.palette` (nix-colors),
# which is set by `./theme.nix` from `shared/palette.nix`.
# This module replaces the static files that previously lived in
# `themes/glats/` with palette-generated `.text` entries.
#
# See the SDD spec at sdd/omarchy-merge/spec for the full palette
# mapping table.
{ config, lib, ... }:

let
  p = config.colorScheme.palette;
in
{
  xdg.configFile = {
    # walker.css - color variables only
    "omarchy/themes/glats/walker.css".text = ''
      @define-color background #${p.base00};
      @define-color foreground #${p.base05};
      @define-color text #${p.base05};
      @define-color accent #${p.base0D};
      @define-color selected-text #${p.base0D};
      @define-color border #${p.base02};
      @define-color base #${p.base00};
    '';

    # waybar.css - color variables only (selectors live in style.css)
    "omarchy/themes/glats/waybar.css".text = ''
      @define-color background #${p.base00};
      @define-color foreground #${p.base05};
      @define-color border #${p.base02};
      @define-color accent #${p.base0D};
      @define-color error #${p.base08};
      @define-color warning #${p.base0A};
      @define-color success #${p.base0B};
      @define-color dim #${p.base03};
      @define-color selected #${p.base02};
      @define-color active-bg #${p.base0D};
      @define-color hover-bg #${p.base02};
    '';

    # hyprland.conf - color-only (no structural keys)
    "omarchy/themes/glats/hyprland.conf".text = ''
      general {
        col.active_border = rgba(${lib.strings.toUpper p.base0D}, 200)
        col.inactive_border = rgba(${lib.strings.toUpper p.base02}, 100)
      }

      decoration {
        shadow {
          color = rgba(${lib.strings.toUpper p.base00}, 0.4)
        }
      }

      group {
        col.border_active = rgba(${lib.strings.toUpper p.base0D}, 200)
        col.border_inactive = rgba(${lib.strings.toUpper p.base02}, 100)
      }
    '';

    # hyprlock.conf - color variables only
    "omarchy/themes/glats/hyprlock.conf".text = ''
      $color = rgba(${p.base00}, 1)
      $inner_color = rgba(${p.base00}, 1)
      $outer_color = rgba(${p.base05}, 0.5)
      $font_color = rgba(${p.base05}, 1)
      $placeholder_color = rgba(${p.base05}, 0.6)
      $check_color = rgba(${p.base0A}, 1.0)
    '';

    # ghostty-theme - 16-color palette (base00-base0F)
    "omarchy/themes/glats/ghostty-theme".text = ''
      palette = 0=#${p.base00}
      palette = 1=#${p.base08}
      palette = 2=#${p.base0B}
      palette = 3=#${p.base0A}
      palette = 4=#${p.base0D}
      palette = 5=#${p.base0E}
      palette = 6=#${p.base0C}
      palette = 7=#${p.base05}
      palette = 8=#${p.base03}
      palette = 9=#${p.base09}
      palette = 10=#${p.base0B}
      palette = 11=#${p.base0A}
      palette = 12=#${p.base0D}
      palette = 13=#${p.base0E}
      palette = 14=#${p.base0C}
      palette = 15=#${p.base07}

      background = #${p.base00}
      foreground = #${p.base05}
      cursor-color = #${p.base05}
      cursor-text = #${p.base00}
      selection-background = #${p.base02}
      selection-foreground = #${p.base05}
    '';

    # btop.theme - colorful gradient mapping
    "omarchy/themes/glats/btop.theme".text = ''
      theme[main_bg]="#${p.base00}"
      theme[main_fg]="#${p.base05}"
      theme[title]="#${p.base05}"
      theme[hi_fg]="#${p.base0D}"
      theme[selected_bg]="#${p.base02}"
      theme[selected_fg]="#${p.base07}"
      theme[inactive_fg]="#${p.base03}"
      theme[graph_text]="#${p.base05}"
      theme[proc_misc]="#${p.base05}"
      theme[cpu_box]="#${p.base0D}"
      theme[mem_box]="#${p.base0D}"
      theme[net_box]="#${p.base0D}"
      theme[proc_box]="#${p.base0D}"
      theme[div_line]="#${p.base02}"
      theme[temp_start]="#${p.base08}"
      theme[temp_mid]="#${p.base0A}"
      theme[temp_end]="#${p.base0B}"
      theme[cpu_start]="#${p.base0D}"
      theme[cpu_mid]="#${p.base0E}"
      theme[cpu_end]="#${p.base0B}"
      theme[free_start]="#${p.base0B}"
      theme[free_mid]="#${p.base03}"
      theme[free_end]="#${p.base05}"
      theme[cached_start]="#${p.base0C}"
      theme[cached_mid]="#${p.base03}"
      theme[cached_end]="#${p.base05}"
      theme[available_start]="#${p.base0B}"
      theme[available_mid]="#${p.base03}"
      theme[available_end]="#${p.base05}"
      theme[used_start]="#${p.base08}"
      theme[used_mid]="#${p.base0A}"
      theme[used_end]="#${p.base0B}"
      theme[download_start]="#${p.base0D}"
      theme[download_mid]="#${p.base0C}"
      theme[download_end]="#${p.base0B}"
      theme[upload_start]="#${p.base0E}"
      theme[upload_mid]="#${p.base0C}"
      theme[upload_end]="#${p.base0B}"
    '';

    # mako.ini - colors + app rules
    "omarchy/themes/glats/mako.ini".text = ''
      include=~/.local/share/omarchy/default/mako/core.ini

      background-color=#${p.base00}
      text-color=#${p.base05}
      border-color=#${p.base0D}
      progress-color=#${p.base0D}

      [app-name=Spotify]
      invisible=1

      [mode=do-not-disturb]
      invisible=true

      [mode=do-not-disturb app-name=notify-send]
      invisible=false
    '';

    # swayosd.css - new file (palette-derived colors)
    "omarchy/themes/glats/swayosd.css".text = ''
      @define-color background-color #${p.base00};
      @define-color border-color #${p.base05};
      @define-color label #${p.base05};
      @define-color image #${p.base05};
      @define-color progress #${p.base05};
    '';

    # kitty.conf - new file (for omarchy theme compatibility)
    "omarchy/themes/glats/kitty.conf".text = ''
      background #${p.base00}
      foreground #${p.base05}
      cursor #${p.base05}
      selection_background #${p.base02}
      selection_foreground #${p.base05}

      color0 #${p.base00}
      color1 #${p.base08}
      color2 #${p.base0B}
      color3 #${p.base0A}
      color4 #${p.base0D}
      color5 #${p.base0E}
      color6 #${p.base0C}
      color7 #${p.base05}
      color8 #${p.base03}
      color9 #${p.base09}
      color10 #${p.base0B}
      color11 #${p.base0A}
      color12 #${p.base0D}
      color13 #${p.base0E}
      color14 #${p.base0C}
      color15 #${p.base07}
    '';

    # alacritty.toml - new file (for omarchy theme compatibility)
    "omarchy/themes/glats/alacritty.toml".text = ''
      [window]
      padding.x = 16
      padding.y = 16

      [font]
      size = 12.0

      [colors.primary]
      background = "#${p.base00}"
      foreground = "#${p.base05}"
      dim_foreground = "#${p.base03}"

      [colors.cursor]
      text = "#${p.base00}"
      cursor = "#${p.base05}"

      [colors.vi_mode_cursor]
      text = "#${p.base00}"
      cursor = "#${p.base05}"

      [colors.selection]
      text = "CellForeground"
      background = "#${p.base02}"
    '';

    # icons.theme - new file (static assignment)
    "omarchy/themes/glats/icons.theme".text = ''
      Papirus-Dark
    '';

    # chromium.theme - new file (static RGB dark)
    "omarchy/themes/glats/chromium.theme".text = ''
      0,0,0
    '';
  };
}
