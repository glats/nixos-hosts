{
  config,
  lib,
  pkgs,
  ...
}:

{
  programs.kitty = {
    enable = lib.mkDefault true;

    settings = lib.mkDefault {
      background_opacity = lib.mkForce "0.9";
      background_tint = "0.2";
      scrollback_lines = -1;
      cursor_shape = "block";
      disable_ligatures = "never";

      window_padding_width = lib.mkForce 0;
      repaint_delay = 10;
      input_delay = 3;
      sync_to_monitor = "yes";

      background = "#${config.colorScheme.palette.base00}";
      foreground = "#${config.colorScheme.palette.base05}";
      cursor = "#${config.colorScheme.palette.base05}";
      selection_background = "#${config.colorScheme.palette.base02}";
      selection_foreground = "#${config.colorScheme.palette.base00}";

      color0 = "#${config.colorScheme.palette.base00}";
      color1 = "#${config.colorScheme.palette.base08}";
      color2 = "#${config.colorScheme.palette.base0B}";
      color3 = "#${config.colorScheme.palette.base0A}";
      color4 = "#${config.colorScheme.palette.base0D}";
      color5 = "#${config.colorScheme.palette.base0E}";
      color6 = "#${config.colorScheme.palette.base0C}";
      color7 = "#${config.colorScheme.palette.base05}";

      color8 = "#${config.colorScheme.palette.base03}";
      color9 = "#${config.colorScheme.palette.base08}";
      color10 = "#${config.colorScheme.palette.base0B}";
      color11 = "#${config.colorScheme.palette.base0A}";
      color12 = "#${config.colorScheme.palette.base0D}";
      color13 = "#${config.colorScheme.palette.base0E}";
      color14 = "#${config.colorScheme.palette.base0C}";
      color15 = "#${config.colorScheme.palette.base07}";

      color16 = "#${config.colorScheme.palette.base09}";
      color17 = "#${config.colorScheme.palette.base0F}";
      color18 = "#${config.colorScheme.palette.base01}";
      color19 = "#${config.colorScheme.palette.base02}";
      color20 = "#${config.colorScheme.palette.base04}";
      color21 = "#${config.colorScheme.palette.base06}";
    };

    font = {
      name = lib.mkDefault "CaskaydiaCove Nerd Font";
      size = lib.mkForce 11;
    };

    keybindings = {
      "kitty_mod+f10" = "toggle_maximized";
    };
  };

  xdg.dataFile."applications/kitty.desktop".text = ''
    [Desktop Entry]
    Name=Kitty
    Comment=Fast, feature-rich terminal emulator
    Exec=${pkgs.kitty}/bin/kitty --start-as maximized %U
    Icon=kitty
    Type=Application
    Categories=System;TerminalEmulator;
    Terminal=false
    StartupNotify=true
    StartupWMClass=kitty
  '';
}
