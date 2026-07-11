{ config
, lib
, pkgs
, ...
}:

let
  cfg = config.hardware.rog.poweroffWorkaround;

  # Direct port I/O poweroff binary.
  # Uses outw(0x2000, 0x604) — the x86 "soft power-off" port.
  # Bypasses ACPI entirely; works on most chipsets.
  rogPoweroffDirect = pkgs.stdenv.mkDerivation {
    name = "rog-poweroff-direct";
    nativeBuildInputs = [ pkgs.glibc.static ];
    phases = [ "buildPhase" ];
    buildPhase = ''
      mkdir -p $out/bin
      cat > $TMPDIR/rog-poweroff.c << 'CEOF'
      #include <sys/io.h>
      #include <unistd.h>

      int main(void) {
          if (iopl(3) < 0)
              return 1;
          outw(0x2000, 0x604);
          return 0;
      }
      CEOF
      cc -O2 -static -o $out/bin/rog-poweroff $TMPDIR/rog-poweroff.c
    '';
  };

  # Legacy hook: unload ASUS WMI modules and call _SI._SST via acpi_call.
  # This was the iteration 2 approach and is kept as fallback.
  rogPoweroffHookLegacy = pkgs.writeShellScript "rog-poweroff-legacy" ''
    # Leave breadcrumb: which mode ran
    echo legacy > /run/rog-poweroff-mode 2>/dev/null || true

    ${pkgs.kmod}/bin/rmmod asus_nb_wmi 2>/dev/null || true
    ${pkgs.kmod}/bin/rmmod asus_armoury 2>/dev/null || true
    ${pkgs.kmod}/bin/rmmod asus_wmi 2>/dev/null || true
    ${pkgs.kmod}/bin/rmmod acpi_call 2>/dev/null || true

    ${pkgs.kmod}/bin/modprobe acpi_call 2>/dev/null || true
    echo '\_SI._SST' > /proc/acpi/call 2>/dev/null || true

    echo "rog-poweroff hook ran" > /run/shutdown-hook-ran || true
  '';

  # Direct hook: bypass ACPI entirely using port I/O.
  rogPoweroffHookDirect = pkgs.writeShellScript "rog-poweroff-direct" ''
    # Leave breadcrumb: which mode ran
    echo direct > /run/rog-poweroff-mode 2>/dev/null || true

    # Direct port I/O poweroff — bypasses ACPI entirely.
    ${rogPoweroffDirect}/bin/rog-poweroff || true

    echo "rog-poweroff hook ran" > /run/shutdown-hook-ran || true
  '';

  selectedHook =
    if cfg.mode == "direct"
    then rogPoweroffHookDirect
    else rogPoweroffHookLegacy;

  selectedStorePaths =
    if cfg.mode == "direct"
    then [ "${rogPoweroffDirect}/bin" ]
    else [ "${pkgs.kmod}/bin" ];
in
{
  options.hardware.rog.poweroffWorkaround = {
    enable = lib.mkEnableOption "ROG late-phase ACPI poweroff workaround" // {
      default = false;
    };

    mode = lib.mkOption {
      type = lib.types.enum [ "legacy" "direct" ];
      default = "legacy";
      description = ''
        Poweroff mode for the ROG shutdown hook.

        - legacy: unload ASUS WMI modules and call \_SI._SST via acpi_call.
          This was the iteration 2 approach.
        - direct: bypass ACPI entirely using port I/O (outw 0x2000, 0x604).
          More likely to work on buggy firmware.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.shutdownRamfs.contents."/etc/systemd/system-shutdown/rog-poweroff" = {
      source = selectedHook;
    };

    systemd.shutdownRamfs.storePaths = selectedStorePaths;
  };
}
