{
  config,
  pkgs,
  ...
}:

{
  # thinkfan-ui — PyQt6 GUI for manual ThinkPad fan control. Pairs with
  # `boot.extraModprobeConfig = "options thinkpad_acpi fan_control=1"`
  # in hosts/t14/default.nix. The two together enable writes to
  # /proc/acpi/ibm/fan. Mutually exclusive with `services.thinkfan`.
  home.packages = with pkgs; [ thinkfan-ui ];

  # Autostart to tray only on Hyprland login — `--hide` starts the app
  # minimized so the window doesn't pop up, only the system-tray icon
  # appears in waybar. XDG Autostart is respected by Hyprland via its
  # xdg-autostart hook (enabled by default).
  xdg.configFile."autostart/thinkfan-ui.desktop".text = ''
    [Desktop Entry]
    Name=ThinkFan UI
    Comment=ThinkPad Fan Control GUI
    Exec=thinkfan-ui --hide
    Icon=${pkgs.thinkfan-ui}/share/icons/thinkfan-ui.svg
    Terminal=false
    Type=Application
    Categories=System;Monitor;
    X-GNOME-Autostart-enabled=true
  '';
}
