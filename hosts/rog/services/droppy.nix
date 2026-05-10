{ config, pkgs, ... }:

{
  # Droppy - Self-hosted file dropzone
  # Config: /srv/glats/droppy/config
  # Data: /run/media/stuff/droppy
  virtualisation.oci-containers.containers.droppy = {
    image = "ghcr.io/droppyjs/droppy:v1.3.1";
    autoStart = true;
    ports = [ "9002:8989" ];
    volumes = [
      "/srv/glats/droppy/config:/config"
      "/run/media/stuff/droppy:/files"
    ];
    environment = {
      UID = "1000";
      GID = "1000";
    };
    extraOptions = [ "--memory=768m" ];
  };
}
