{ config, lib, ... }:
{
  options.my.desktop.suite = lib.mkOption {
    type = lib.types.nullOr (lib.types.enum [ "mate" "gnome" ]);
    default = null;
    description = "Desktop suite to enable for this host. mate = MATE desktop, gnome = GNOME apps alongside omarchy/Hyprland.";
  };
}
