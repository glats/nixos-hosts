{
  config,
  pkgs,
  inputs,
  ...
}:

{
  imports = [ inputs.nix-colors.homeManagerModules.default ];

  colorScheme = import ../shared/palette.nix;

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
      .caja-desktop.view .entry, .caja-navigation-window .view .entry {caret-color: #${config.colorScheme.palette.base07};}

      /* Fix: selected items invisible when window unfocused (backdrop state) */
      /* Redefinir colores del tema para selecciones sin foco */
      @define-color theme_unfocused_selected_bg_color #${config.colorScheme.palette.base02};
      @define-color theme_unfocused_selected_fg_color #${config.colorScheme.palette.base07};

      /* Override generico para cualquier seleccion en backdrop */
      *:backdrop:selected {
        background-color: #${config.colorScheme.palette.base02} !important;
        color: #${config.colorScheme.palette.base07} !important;
      }

      .view:backdrop:selected {
        background-color: #${config.colorScheme.palette.base02} !important;
        color: #${config.colorScheme.palette.base07} !important;
      }

      row:backdrop:selected {
        background-color: #${config.colorScheme.palette.base02} !important;
        color: #${config.colorScheme.palette.base07} !important;
      }
    '';
    gtk4.extraConfig = {
      gtk-application-prefer-dark-theme = true;
    };
    # Explicitly set gtk4 theme to silence home-manager warning
    gtk4.theme = config.gtk.theme;
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
