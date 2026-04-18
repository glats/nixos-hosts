{ config, pkgs, ... }:

{
  # Fileshelter - File Upload Service
  # Datos en /srv/glats/fileshelter/
  virtualisation.oci-containers.containers.fileshelter = {
    image = "epoupon/fileshelter";
    autoStart = true;

    user = "1000:1000";

    ports = [
      "5091:5091"
    ];

    volumes = [
      "/srv/glats/fileshelter/fileshelter.conf:/etc/fileshelter.conf"
      "/srv/glats/fileshelter/uploads:/var/fileshelter/uploaded-files"
      "/srv/glats/fileshelter/data:/var/fileshelter"
    ];

    extraOptions = [
      "--memory=512m"
    ];
  };
}
