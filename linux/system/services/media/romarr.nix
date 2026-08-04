{ config, pkgs, ... }:

{
  # Romarr — self-hosted ROM acquisition manager (Sonarr for ROMs).
  # Host network: reaches qBittorrent:8080 and Prowlarr:9696 on localhost.
  # Self-contained with SQLite — no external DB needed.

  # ── Secrets generation ────────────────────────────────────────────
  systemd.services.romarr-secrets = {
    description = "Generate Romarr env file";
    before = [ "docker-romarr.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = pkgs.writeShellScript "generate-romarr-secrets" ''
        mkdir -p /srv/glats/romarr
        cat ${config.sops.secrets."romarr-env-secret".path} > /srv/glats/romarr/romarr.env
      '';
    };
  };

  virtualisation.oci-containers.containers.romarr = {
    image = "sharkhunterr/romarr:latest";
    autoStart = true;

    volumes = [
      "/srv/glats/romarr/data:/data"
      "/srv/glats/downloads:/downloads:ro"
      "/run/media/library/roms:/library/roms"
    ];

    environment = {
      TZ = "America/Santiago";
      PUID = "1000";
      PGID = "1000";
    };

    environmentFiles = [
      "/srv/glats/romarr/romarr.env"
    ];

    extraOptions = [ "--network=host" ];
  };

  systemd.tmpfiles.rules = [
    "d /srv/glats/romarr 0755 root root -"
    "d /srv/glats/romarr/data 0755 root root -"
  ];

  systemd.services."docker-romarr".after = [ "qbittorrent-nox.service" ];
}
