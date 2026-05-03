{ config, lib, pkgs, ... }:

{
  options.boot-settings = {
    enable = lib.mkEnableOption "shared boot configuration";
    includeAcpiOsi = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Include ACPI OSI overrides (for ASUS laptops)";
    };
  };

  config = lib.mkIf config.boot-settings.enable {
    boot = {
      loader.systemd-boot.enable = true;
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
      ] ++ lib.optionals config.boot-settings.includeAcpiOsi [
        "acpi_osi=!"
        "acpi_osi=\"Windows 2018\""
      ];
    };
  };
}
