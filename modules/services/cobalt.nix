{ config, pkgs, ... }:

{
  # Cobalt - Media Downloader
  # Datos en /srv/glats/cobalt/
  virtualisation.oci-containers.containers.cobalt = {
    image = "ghcr.io/imputnet/cobalt:11.4.1";
    autoStart = true;

    ports = [
      "9015:9015"
    ];

    volumes = [
      "/srv/glats/cobalt/cookies.json:/app/cookies.json"
    ];

    environment = {
      COOKIE_PATH = "/app/cookies.json";
      API_URL = "http://localhost:9015/";
      API_PORT = "9015";
      DISABLED_SERVICES = "youtube";
    };

    extraOptions = [
      "--init"
      "--read-only"
      "--memory=256m"
    ];
  };
}
