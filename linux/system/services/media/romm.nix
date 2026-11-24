{ config, pkgs, ... }:

let
  rommPort = 8081;

  rommConfig = pkgs.writeText "romm-config.yml" ''
    scan:
      priority:
        metadata:
          - "igdb"
          - "ss"
          - "moby"
          - "launchbox"
          - "hasheous"
          - "ra"
          - "gamelist"
          - "tgdb"
          - "flashpoint"
          - "hltb"
        artwork:
          - "ss"
          - "igdb"
          - "moby"
          - "sgdb"
          - "libretro"
          - "launchbox"
          - "hasheous"
          - "ra"
          - "tgdb"
          - "flashpoint"
        cover:
          - "ss"
          - "igdb"
          - "libretro"
          - "hasheous"
        screenshot:
          - "ss"
          - "igdb"
          - "moby"
        region:
          - "us"
          - "wor"
          - "ss"
          - "eu"
          - "jp"
        language:
          - "en"
          - "es"
          - "fr"
      media:
        - "box2d"
        - "box3d"
        - "miximage"
        - "screenshot"
        - "title_screen"
        - "marquee"
  '';
in
{

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

  systemd.services.romm-config = {
    description = "Render RomM config.yml";
    after = [ "docker-network-romm.service" ];
    before = [ "docker-romm.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = pkgs.writeShellScript "render-romm-config" ''
        mkdir -p /srv/glats/romm/config
        target=/srv/glats/romm/config/config.yml
        if [ -f "$target" ] && ${pkgs.coreutils}/bin/cmp -s ${rommConfig} "$target"; then
          echo "RomM config unchanged"
        else
          ${pkgs.coreutils}/bin/install -m 0644 ${rommConfig} "$target"
          echo "RomM config updated"
        fi
      '';
    };
  };

  virtualisation.oci-containers.containers.romm-db = {
    image = "mariadb:11";
    autoStart = true;

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

      ROMM_BASE_URL = "https://roms.glats.org";

      # Zero-key metadata providers.
      HASHEOUS_API_ENABLED = "true";
      LAUNCHBOX_API_ENABLED = "true";
      ENABLE_SCHEDULED_UPDATE_LAUNCHBOX_METADATA = "true";

      # Keep the catalog in sync with the library disk.
      ENABLE_RESCAN_ON_FILESYSTEM_CHANGE = "true";
      RESCAN_ON_FILESYSTEM_CHANGE_DELAY = "5";
      ENABLE_SCHEDULED_RESCAN = "true";
      SCHEDULED_RESCAN_CRON = "0 3 * * *";
      SCAN_TIMEOUT = "28800";
      TASK_TIMEOUT = "28800";
    };

    environmentFiles = [
      "/srv/glats/romm/romm.env"
    ];

    dependsOn = [ "romm-db" ];
  };

  systemd.tmpfiles.rules = [
    "d /srv/glats/romm 0755 root root -"
    "d /srv/glats/romm/mariadb 0755 root root -"
    "d /srv/glats/romm/resources 0755 root root -"
    "d /srv/glats/romm/redis-data 0755 root root -"
    "d /srv/glats/romm/assets 0755 root root -"
    "d /srv/glats/romm/config 0755 root root -"
  ];
}
