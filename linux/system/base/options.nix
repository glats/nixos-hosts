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
    # using the previous xorgxrdp. services.xrdp sets restartIfChanged = false
    # so that ordinary switches never kill running RDP sessions, which leaves
    # the sesman stale whenever the xrdp package itself changes. Restart it
    # exactly in that case: the xrdp daemon restarts anyway when the package
    # changes, so the transport is dropped either way.
    #
    # This lives here rather than in services/xrdp.nix because the two XRDP
    # hosts enable services.xrdp in different ways: rog imports the shared
    # xrdp module, thinkcentre configures services.xrdp inline.
    systemd.services.xrdp-sesman.restartTriggers = [ config.services.xrdp.package ];
  };
}
