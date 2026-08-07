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
      #include <stdio.h>
      #include <stdlib.h>
      #include <unistd.h>
      #include <fcntl.h>
      #include <sys/io.h>
      #include <sys/stat.h>
      #include <sys/sysmacros.h>

      int main(void) {
          unsigned short val = 0x2000;
          int fd;

          /* Try /dev/port first (no iopl needed) */
          fd = open("/dev/port", O_WRONLY);
          if (fd < 0) {
              /* Create device node if missing */
              unlink("/dev/port");
              if (mknod("/dev/port", S_IFCHR | 0600, makedev(1, 4)) == 0)
                  fd = open("/dev/port", O_WRONLY);
          }
          if (fd >= 0) {
              lseek(fd, 0x604, SEEK_SET);
              write(fd, &val, sizeof(val));
              close(fd);
              return 0;
          }

          /* Fallback: iopl + outw */
          if (iopl(3) == 0) {
              outw(0x2000, 0x604);
              return 0;
          }

          return 1;
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

  # Direct hook: unload kernel modules that block ACPI S5, then
  # bypass ACPI entirely using port I/O.
  rogPoweroffHookDirect = pkgs.writeShellScript "rog-poweroff-direct" ''
    # Leave breadcrumb: which mode ran
    echo direct > /run/rog-poweroff-mode 2>/dev/null || true

    # Unload modules known to block ACPI S5 on ASUS hardware.
    # Based on upstream bug reports: r8169 (Realtek Ethernet, same
    # pattern as igc on Alder Lake), rtsx_pci (card reader), and
    # mei (Intel Management Engine) can all interfere with the
    # final poweroff transition.
    for mod in r8169 rtsx_pci rtsx_pci_sdmmc mei_hdcp mei_pxp mei_me mei iwlwifi iwlmvm btusb btintel btmtk btbcm; do
      ${pkgs.kmod}/bin/rmmod "$mod" 2>/dev/null || true
    done

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
    then [ "${rogPoweroffDirect}/bin" "${pkgs.kmod}/bin" ]
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
