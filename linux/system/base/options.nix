{ config, lib, ... }:
{
  options.my.desktop.suite = lib.mkOption {
    type = lib.types.enum [
      null
      "mate"
      "gnome"
    ];
    default = null;
    description = "Desktop suite to enable for this host. null = no desktop suite, mate = MATE desktop, gnome = GNOME apps alongside omarchy/Hyprland.";
  };
}
