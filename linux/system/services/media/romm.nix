{ config, pkgs, ... }:

let
  rommPort = 8081; # 8080 taken by qBittorrent native module
in
{
  # RomM — self-hosted ROM catalog manager (Netflix-style library browser).
  # Bridge network: MariaDB + RomM app. Same pattern as authelia.

  # ── Docker bridge network ───────────────────────────────────────────
  systemd.services.docker-network-romm = {
    description = "Docker network for RomM";
    after = [ "docker.service" ];
    requires = [ "docker.service" ];
    before = [
      "docker-romm-db.service"
      "docker-romm.service"
    ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = pkgs.writeShellScript "create-romm-network" ''
        if ! ${pkgs.docker}/bin/docker network ls --format '{{.Name}}' 2>/dev/null | grep -q "^romm$"; then
          echo "Creating romm docker network..."
          ${pkgs.docker}/bin/docker network create \
            --driver bridge \
            --subnet 10.92.0.0/24 \
            --gateway 10.92.0.1 \
            romm 2>/dev/null || true
        fi
      '';
    };
  };

  # ── Secrets generation (oneshot) ────────────────────────────────────
  systemd.services.romm-secrets = {
    description = "Generate RomM secrets files";
    after = [ "docker-network-romm.service" ];
    before = [
      "docker-romm-db.service"
      "docker-romm.service"
    ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = pkgs.writeShellScript "generate-romm-secrets" ''
        mkdir -p /srv/glats/romm

        ROOT_PW=$(cat ${config.sops.secrets."romm/db_root_password".path})
        USER_PW=$(cat ${config.sops.secrets."romm/db_user_password".path})
        AUTH_KEY=$(cat ${config.sops.secrets."romm/auth_secret_key".path})

        # MariaDB — includes user + database auto-creation on first run
        cat > /srv/glats/romm/db_root.env <<ENV
        MARIADB_ROOT_PASSWORD=$ROOT_PW
        MARIADB_USER=romm
        MARIADB_PASSWORD=$USER_PW
        MARIADB_DATABASE=romm
        ENV

        # RomM app
        cat > /srv/glats/romm/romm.env <<ENV
        ROMM_AUTH_SECRET_KEY=$AUTH_KEY
        ROMM_DB_DRIVER=mariadb
        DB_HOST=romm-db
        DB_PORT=3306
        DB_USER=romm
        DB_PASSWD=$USER_PW
        DB_NAME=romm
        ENV
      '';
    };
  };

  # ── MariaDB container ───────────────────────────────────────────────
  virtualisation.oci-containers.containers.romm-db = {
    image = "mariadb:11";
    autoStart = true;

    # Docker default 10s stop timeout isn't enough for MariaDB
    # to dump buffer pool + flush logs → SIGKILL → corrupt tc.log.
    # 120s gives InnoDB time to "Shutdown completed" cleanly.
    # --log-bin eliminates tc.log entirely: MariaDB uses binlog for
    # crash recovery instead of the memory-mapped tc.log file which
    # corrupts on every unclean shutdown.
    extraOptions = [
      "--network=romm"
      "--stop-timeout=120"
    ];

    volumes = [
      "/srv/glats/romm/mariadb:/var/lib/mysql"
      "/srv/glats/romm/mariadb.cnf:/etc/mysql/conf.d/binlog.cnf:ro"
    ];

    environmentFiles = [
      "/srv/glats/romm/db_root.env"
    ];
  };

  # ── RomM app container ──────────────────────────────────────────────
  virtualisation.oci-containers.containers.romm = {
    image = "rommapp/romm:latest";
    autoStart = true;

    ports = [ "127.0.0.1:${toString rommPort}:8080" ];

    extraOptions = [ "--network=romm" ];

    volumes = [
      "/srv/glats/romm/resources:/romm/resources"
      "/srv/glats/romm/redis-data:/redis-data"
      "/srv/glats/romm/assets:/romm/assets"
      "/srv/glats/romm/config:/romm/config"
      "/run/media/library:/romm/library:ro"
    ];

    environment = {
      ROMM_DB_DRIVER = "mariadb";
      DB_HOST = "romm-db";
      DB_PORT = "3306";
      DB_USER = "romm";
      DB_NAME = "romm";
    };

    environmentFiles = [
      "/srv/glats/romm/romm.env"
    ];

    dependsOn = [ "romm-db" ];
  };

  # ── Directories ─────────────────────────────────────────────────────
  systemd.tmpfiles.rules = [
    "d /srv/glats/romm 0755 root root -"
    "d /srv/glats/romm/mariadb 0755 root root -"
    "d /srv/glats/romm/resources 0755 root root -"
    "d /srv/glats/romm/redis-data 0755 root root -"
    "d /srv/glats/romm/assets 0755 root root -"
    "d /srv/glats/romm/config 0755 root root -"
  ];
}
