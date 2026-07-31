{ lib, config, ... }:

let
  cfg = config.my.gamepad;
in
{
  options.my.gamepad = {
    enable = lib.mkEnableOption "Xbox/PS/Nintendo gamepad support (kernel + udev)";
  };

  config = lib.mkIf cfg.enable {
    # Xbox One/Series wireless (xpadneo). Wired controllers work via
    # the kernel's built-in xpad driver without this module.
    hardware.xpadneo.enable = true;

    # Required by xpadneo for force-feedback and by some emulators that
    # use the uinput interface for virtual gamepad devices.
    boot.kernelModules = [ "uinput" ];

    # udev rules — grant plugdev group read/write access to common
    # gamepad USB vendor IDs so RetroArch/SDL2 can open the device
    # without root. TAG+="uaccess" makes the device accessible to the
    # physically-logged-in user via logind ACLs.
    services.udev.extraRules = ''
      # Xbox (045e), PlayStation (054c), Nintendo (057e)
      SUBSYSTEM=="input", ATTRS{idVendor}=="045e", MODE="0660", GROUP="plugdev", TAG+="uaccess"
      SUBSYSTEM=="input", ATTRS{idVendor}=="054c", MODE="0660", GROUP="plugdev", TAG+="uaccess"
      SUBSYSTEM=="input", ATTRS{idVendor}=="057e", MODE="0660", GROUP="plugdev", TAG+="uaccess"
      KERNEL=="js[0-9]*", MODE="0660", GROUP="plugdev"
    '';
  };
}
