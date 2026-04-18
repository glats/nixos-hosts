{ pkgs, inputs, ... }:

{
  imports = [ inputs.nix-colors.homeManagerModules.default ];

  colorScheme = {
    slug = "glats";
    name = "Glats";
    author = "Custom";
    palette = {
      base00 = "000000";
      base01 = "0a0a0a";
      base02 = "505050";
      base03 = "8a8a8a";
      base04 = "a0a0a0";
      base05 = "dddddd";
      base06 = "d0d0d0";
      base07 = "ffffff";
      base08 = "cc0403";
      base09 = "f2201f";
      base0A = "cecb00";
      base0B = "19cb00";
      base0C = "0dcdcd";
      base0D = "0d73cc";
      base0E = "cb1ed1";
      base0F = "ff6600";

      brightGreen = "23fd00";
      brightYellow = "fffd00";
      brightBlue = "1a8fff";
      brightMagenta = "fd28ff";
      brightCyan = "14ffff";
    };
  };

  gtk = {
    enable = true;
    theme.name = "Materia-dark-compact";
    theme.package = pkgs.materia-theme;
    iconTheme.name = "Papirus-Dark";
    iconTheme.package = pkgs.papirus-icon-theme;
    gtk3.extraConfig = {
      gtk-application-prefer-dark-theme = true;
    };
    gtk3.extraCss = ''
      .caja-desktop.view .entry, .caja-navigation-window .view .entry {caret-color: white;}

      /* Fix: selected items invisible when window unfocused (backdrop state) */
      /* Redefinir colores del tema para selecciones sin foco */
      @define-color theme_unfocused_selected_bg_color #505050;
      @define-color theme_unfocused_selected_fg_color #ffffff;

      /* Override generico para cualquier seleccion en backdrop */
      *:backdrop:selected {
        background-color: #505050 !important;
        color: #ffffff !important;
      }

      .view:backdrop:selected {
        background-color: #505050 !important;
        color: #ffffff !important;
      }

      row:backdrop:selected {
        background-color: #505050 !important;
        color: #ffffff !important;
      }
    '';
    gtk4.extraConfig = {
      gtk-application-prefer-dark-theme = true;
    };
  };

  qt = {
    enable = true;
    platformTheme.name = "gtk";
    style.name = "adwaita-dark";
  };

  dconf.settings."org/gnome/desktop/interface" = {
    color-scheme = "prefer-dark";
  };
}
