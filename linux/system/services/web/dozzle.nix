{ config, pkgs, ... }:

{
  virtualisation.oci-containers.containers.dozzle = {
    image = "amir20/dozzle:latest";
    autoStart = true;

    ports = [
      "9016:8080"
    ];

    volumes = [
      "/var/run/docker.sock:/var/run/docker.sock:ro"
    ];

    environment = {
      DOZZLE_LEVEL = "info";
    };

    extraOptions = [
      "--memory=256m"
    ];
  };
}
