{ config, pkgs, ... }:

{
  virtualisation.oci-containers.containers.jellyseerr = {
    image = "fallenbagel/jellyseerr:2.5.0";
    autoStart = true;

    extraOptions = [ "--network=host" ];

    volumes = [
      "/srv/glats/jellyseerr/config:/app/config"
    ];

    environment = {
      LOG_LEVEL = "info";
    };
  };

  systemd.tmpfiles.rules = [
    "d /srv/glats/jellyseerr 0755 root root -"
    "d /srv/glats/jellyseerr/config 0755 1000 1000 -"
  ];

  systemd.services."docker-jellyseerr".preStart = ''
    mkdir -p /srv/glats/jellyseerr/config
    chmod 755 /srv/glats/jellyseerr /srv/glats/jellyseerr/config
  '';
}
