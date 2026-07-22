{ config
, lib
, pkgs
, ...
}:

{
  options.boot-settings = {
    enable = lib.mkEnableOption "shared boot configuration";
    includeAcpiOsi = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Include ACPI OSI overrides (for ASUS laptops)";
    };
    includePoweroffFix = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Include ACPI poweroff fix kernel params (for ASUS ROG)";
    };
    includeDiagLogging = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Append verbose kernel and systemd logging params (loglevel=7,
        systemd.log_level=debug, systemd.log_target=console) to the
        kernel command line. Intended for hosts that experience
        shutdown hangs and need to capture full kernel/systemd output
        to a console for post-mortem. Off by default because it
        clutters the TTY and may interact poorly with Plymouth.
      '';
    };
  };

  config = lib.mkIf config.boot-settings.enable {
    boot = {
      loader.systemd-boot = {
        enable = true;
        configurationLimit = 3;
      };
      loader.efi.canTouchEfiVariables = true;
      plymouth.enable = true;
      consoleLogLevel = 0;
      initrd.verbose = false;
      kernelPackages = pkgs.linuxPackages_zen;
      kernelParams = [
        "quiet"
        "splash"
        "boot.shell_on_fail"
        "loglevel=3"
        "rd.systemd.show_status=false"
        "rd.udev.log_level=3"
        "udev.log_priority=3"
        "vt.global_cursor_default=0"
      ]
      ++ lib.optionals config.boot-settings.includeAcpiOsi [
        "acpi_osi=!"
        "acpi_osi=\"Windows 2018\""
      ]
      ++ lib.optionals config.boot-settings.includePoweroffFix [
        "acpi=force"
        "pcie_aspm=off"
        "reboot=acpi"
      ]
      ++ lib.optionals config.boot-settings.includeDiagLogging [
        # Kernel uses the last occurrence when the same key appears
        # twice, so this 7 wins over the static 3 above.
        "loglevel=7"
        "systemd.log_level=debug"
        "systemd.log_target=console"
      ];
    };
  };
}
