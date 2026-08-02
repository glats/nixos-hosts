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

    # Xbox controller Bluetooth pairing requires specific bluez settings.
    # Privacy=device is essential for BLE controllers (firmware 5.x+).
    # FastConnectable avoids the connect/disconnect loop.
    # ControllerMode=dual enables both BR/EDR and LE.
    hardware.bluetooth = {
      enable = true;
      powerOnBoot = true;
      settings = {
        General = {
          Privacy = "device";
          JustWorksRepairing = "always";
          FastConnectable = "true";
          ControllerMode = "dual";
        };
      };
    };

    # BlueZ 2024+ defaults UserspaceHID=true which breaks Xbox BLE HID.
    # Must be false for xpadneo to receive input events.
    environment.etc."bluetooth/input.conf" = {
      text = lib.mkForce ''
        [General]
        UserspaceHID=false
      '';
      mode = "0444";
    };

    # Disable ERTM — conflicts with Xbox controller Bluetooth stack.
    # Causes connect/disconnect loops and pairing failures.
    # lib.mkAfter: merges with t14's thinkpad_acpi modprobe config.
    boot.extraModprobeConfig = lib.mkAfter ''
      options bluetooth disable_ertm=1
    '';

    # udev rules — grant plugdev group read/write access to common
    # gamepad USB vendor IDs so RetroArch/SDL2 can open the device
    # without root. TAG+="uaccess" makes the device accessible to the
    # physically-logged-in user via logind ACLs.
    services.udev.extraRules = lib.mkAfter ''
      # Xbox (045e), PlayStation (054c), Nintendo (057e)
      SUBSYSTEM=="input", ATTRS{idVendor}=="045e", MODE="0660", GROUP="plugdev", TAG+="uaccess"
      SUBSYSTEM=="input", ATTRS{idVendor}=="054c", MODE="0660", GROUP="plugdev", TAG+="uaccess"
      SUBSYSTEM=="input", ATTRS{idVendor}=="057e", MODE="0660", GROUP="plugdev", TAG+="uaccess"
      KERNEL=="js[0-9]*", MODE="0660", GROUP="plugdev"
    '';
  };
}
