{ config, lib, ... }:

let
  cfg = config.corporate.compliance;
in
{
  options.corporate.compliance.enable = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = ''
      Selects the integrated corporate-compliance components for this host.
      This gates the generated configuration; it does not enroll the device.
    '';
  };

  config = {
    environment.etc."corporate-compliance/mode".text = if cfg.enable then "on\n" else "off\n";

    specialisation.compliance-off.configuration = {
      corporate.compliance.enable = lib.mkForce false;
    };
  };
}
