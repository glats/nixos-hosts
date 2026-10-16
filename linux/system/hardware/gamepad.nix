{ lib, config, ... }:

let
  cfg = config.my.gamepad;
in
{
  options.my.gamepad = {
    enable = lib.mkEnableOption "Xbox/PS/Nintendo gamepad support (kernel + udev)";
  };

  config = lib.mkIf cfg.enable {
    hardware.xpadneo.enable = true;

    boot.kernelModules = [ "uinput" ];

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

    environment.etc."bluetooth/input.conf" = {
      text = lib.mkForce ''
        [General]
        UserspaceHID=false
      '';
      mode = "0444";
    };

    boot.extraModprobeConfig = lib.mkAfter ''
      options bluetooth disable_ertm=1
    '';

    services.udev.extraRules = lib.mkAfter ''
      # Xbox (045e), PlayStation (054c), Nintendo (057e)
      SUBSYSTEM=="input", ATTRS{idVendor}=="045e", MODE="0660", GROUP="plugdev", TAG+="uaccess"
      SUBSYSTEM=="input", ATTRS{idVendor}=="054c", MODE="0660", GROUP="plugdev", TAG+="uaccess"
      SUBSYSTEM=="input", ATTRS{idVendor}=="057e", MODE="0660", GROUP="plugdev", TAG+="uaccess"
      KERNEL=="js[0-9]*", MODE="0660", GROUP="plugdev"
    '';
  };
}
