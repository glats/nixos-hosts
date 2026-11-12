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

  config = lib.mkIf config.services.xrdp.enable {
    # xrdp-sesman reads sesman.ini once at startup and keeps the session X
    # server module path from it, so a sesman that survives a switch keeps
    # using the previous xorgxrdp and the previous session configuration.
    # services.xrdp sets restartIfChanged = false so that ordinary switches
    # never kill running RDP sessions.
    #
    # That flag also makes restartTriggers inert: switch-to-configuration
    # skips any unit carrying X-RestartIfChanged=false before it evaluates
    # the triggers. Enabling the restart for this unit is what actually
    # replaces a stale sesman. Its ExecStart embeds the xrdp package path, so
    # the unit only changes when that package changes, which is exactly when
    # the sesman must be replaced. Ordinary switches leave the unit
    # byte-identical and the running sessions alone.
    #
    # This lives here rather than in services/xrdp.nix because the XRDP hosts
    # enable services.xrdp in different ways: rog and samsung import the
    # shared xrdp module, thinkcentre configures services.xrdp inline.
    systemd.services.xrdp-sesman.restartIfChanged = lib.mkForce true;
  };
}
