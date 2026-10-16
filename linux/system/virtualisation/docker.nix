{ config, lib, ... }:

{
  options.virtualisation.docker-custom = {
    enable = lib.mkEnableOption "Docker virtualisation backend" // {
      default = true;
    };
  };

  config = lib.mkIf config.virtualisation.docker-custom.enable {
    virtualisation.docker.enable = true;

    virtualisation.oci-containers.backend = "docker";
  };
}
