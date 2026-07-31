{ config, lib, ... }:

{
  options.networking.firewall-custom = {
    enable = lib.mkEnableOption "custom firewall configuration" // {
      default = true;
    };
  };

  config = lib.mkIf config.networking.firewall-custom.enable {
    # Disables NixOS firewall.
    networking.firewall.enable = false;
  };
}
