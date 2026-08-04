{ config, pkgs, ... }:

{
  # Grabarr — Torznab bridge for ROM repositories
  # (Vimm's Lair, Edge Emulation, Myrient, RomsFun, CDRomance…)
  # Accessible at http://127.0.0.1:45454 via host networking.
  # Used by Romarr as its primary ROM indexer.

  virtualisation.oci-containers.containers.grabarr = {
    image = "sharkhunterr/grabarr:latest";
    autoStart = true;

    volumes = [
      "/srv/glats/grabarr:/data"
    ];

    environment = {
      TZ = "America/Santiago";
      PUID = "1000";
      PGID = "1000";
    };

    cmd = [
      "uvicorn"
      "grabarr.api.app:app"
      "--host"
      "0.0.0.0"
      "--port"
      "45454"
    ];

    extraOptions = [ "--network=host" ];
  };

  systemd.tmpfiles.rules = [
    "d /srv/glats/grabarr 0755 root root -"
  ];
}
