{ config
, lib
, pkgs
, ...
}:

let
  cfg = config.hardware.rog.poweroffWorkaround;

  rogPoweroffHook = pkgs.writeShellScript "rog-poweroff" ''
    # Late shutdown hook for ROG systems.
    # This runs in the shutdown ramfs after systemd-shutdown pivot.
    # Commands are best-effort and must never block shutdown.

    ${pkgs.kmod}/bin/rmmod asus_nb_wmi 2>/dev/null || true
    ${pkgs.kmod}/bin/rmmod asus_armoury 2>/dev/null || true
    ${pkgs.kmod}/bin/rmmod asus_wmi 2>/dev/null || true
    ${pkgs.kmod}/bin/rmmod acpi_call 2>/dev/null || true

    ${pkgs.kmod}/bin/modprobe acpi_call 2>/dev/null || true
    echo '\_SI._SST' > /proc/acpi/call 2>/dev/null || true

    echo "rog-poweroff hook ran" > /run/shutdown-hook-ran || true
  '';
in
{
  options.hardware.rog.poweroffWorkaround = {
    enable = lib.mkEnableOption "ROG late-phase ACPI poweroff workaround" // {
      default = false;
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.shutdownRamfs.contents."/etc/systemd/system-shutdown/rog-poweroff" = {
      source = rogPoweroffHook;
    };

    systemd.shutdownRamfs.storePaths = [
      "${pkgs.kmod}/bin"
    ];
  };
}
