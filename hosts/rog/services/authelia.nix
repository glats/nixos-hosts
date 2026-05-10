{ config, pkgs, ... }:

let
  # Generate users.yml with bcrypt password
  usersYml = pkgs.writeText "authelia-users.yml" ''
    users:
      glats:
        disabled: false
        displayname: "Glats"
        password: "$2b$10$TG4omZ.BGswarpI1tsZer.WuG3QTp/WRSAkxsSYvTOv5uejeCBi1K"
        email: glats@glats.org
        groups:
          - admins
  '';
in
{
  # Authelia SSO Service
  # Protects: openfang.glats.org
  # Portal: auth.glats.org
  # Storage: PostgreSQL (authelia DB via Docker)
  # Sessions: Redis (via Docker)

  # Ensure authelia network exists
  systemd.services.docker-network-authelia = {
    description = "Docker network for Authelia";
    after = [ "docker.service" ];
    requires = [ "docker.service" ];
    before = [
      "docker-autheliadb.service"
      "docker-authelia-redis.service"
      "docker-authelia.service"
    ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = pkgs.writeShellScript "create-authelia-network" ''
        if ! ${pkgs.docker}/bin/docker network ls --format '{{.Name}}' 2>/dev/null | grep -q "^authelia$"; then
          echo "Creating authelia docker network..."
          ${pkgs.docker}/bin/docker network create \
            --driver bridge \
            --subnet 10.91.0.0/24 \
            --gateway 10.91.0.1 \
            authelia 2>/dev/null || true
        else
          echo "Authelia network already exists"
        fi
      '';
    };
  };

  # Generate secrets for all containers
  systemd.services.authelia-secrets = {
    description = "Generate Authelia secrets files";
    after = [ "docker-network-authelia.service" ];
    before = [
      "docker-autheliadb.service"
      "docker-authelia-redis.service"
      "docker-authelia.service"
    ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = pkgs.writeShellScript "generate-authelia-secrets" ''
                mkdir -p /srv/glats/authelia /srv/glats/authelia/redis

                # Read secret values directly from sops decrypted files
                JWT_SECRET=$(cat ${config.sops.secrets."authelia/jwt_secret".path})
                SESSION_SECRET=$(cat ${config.sops.secrets."authelia/session_secret".path})
                STORAGE_KEY=$(cat ${config.sops.secrets."authelia/storage_encryption_key".path})
                POSTGRES_PASSWORD=$(cat ${config.sops.secrets."authelia/postgresql_password".path})
                REDIS_PASSWORD=$(cat ${config.sops.secrets."authelia/redis_password".path})

                # Write environment file for Authelia container
                cat > /srv/glats/authelia/authelia.env <<ENVFILE
        AUTHELIA_JWT_SECRET=$JWT_SECRET
        AUTHELIA_SESSION_SECRET=$SESSION_SECRET
        AUTHELIA_STORAGE_ENCRYPTION_KEY=$STORAGE_KEY
        AUTHELIA_STORAGE_POSTGRES_PASSWORD=$POSTGRES_PASSWORD
        AUTHELIA_REDIS_PASSWORD=$REDIS_PASSWORD
        POSTGRES_PASSWORD=$POSTGRES_PASSWORD
        ENVFILE

                # Write postgres-specific env file for PostgreSQL container
                cat > /srv/glats/authelia/postgres.env <<ENVFILE
        POSTGRES_PASSWORD=$POSTGRES_PASSWORD
        ENVFILE

                # Write Redis config file (no password for internal network)
                cat > /srv/glats/authelia/redis/redis.conf <<CONF
        bind 0.0.0.0
        protected-mode no
        appendonly no
        save ""
        CONF

                # Write authelia config with env var substitution
                cat > /srv/glats/authelia/configuration.yml <<YAML
        server:
              address: tcp://0.0.0.0:9091

        log:
          level: info
          format: text

        session:
          name: authelia_session
          same_site: lax
          expiration: 1h
          inactivity: 5m
          remember_me: 1M
          redis:
            host: authelia-redis
            port: 6379
            database_index: 0
          cookies:
            - name: authelia_session
              domain: glats.org
              same_site: lax
              authelia_url: https://auth.glats.org/
              default_redirection_url: https://openfang.glats.org/

        storage:
          encryption_key: \$AUTHELIA_STORAGE_ENCRYPTION_KEY
          postgres:
            address: tcp://autheliadb:5432
            database: authelia
            schema: public
            username: authelia

        access_control:
          default_policy: one_factor

          rules:
            - domain: "auth.glats.org"
              policy: bypass

            - domain: "*.glats.org"
              networks:
                - 192.168.0.0/16
                - 10.0.0.0/8
                - 172.16.0.0/12
                - 127.0.0.1/8
              policy: bypass

        authentication_backend:
          file:
            path: /config/users.yml
            password:
              algorithm: argon2id
              iterations: 1
              key_length: 32
              salt_length: 16
              memory: 64
              parallelism: 8

        notifier:
          filesystem:
            filename: /config/notification.txt

        identity_validation:
          reset_password:
            jwt_secret: \$AUTHELIA_JWT_SECRET

        theme: auto
        YAML

                # Remove any old config files that might conflict
                rm -f /srv/glats/authelia/authelia.yml /srv/glats/authelia/configuration.yml.bak

                # Copy users.yml and create notification file
                cp ${usersYml} /srv/glats/authelia/users.yml
                touch /srv/glats/authelia/notification.txt
                chmod 600 /srv/glats/authelia/authelia.env /srv/glats/authelia/postgres.env /srv/glats/authelia/redis/redis.conf /srv/glats/authelia/configuration.yml /srv/glats/authelia/users.yml
                chmod 644 /srv/glats/authelia/notification.txt
      '';
    };
  };

  # PostgreSQL for Authelia
  virtualisation.oci-containers.containers.autheliadb = {
    image = "postgres:17-alpine";
    autoStart = true;

    volumes = [
      "/srv/glats/authelia/dbdata:/var/lib/postgresql/data"
    ];

    environmentFiles = [
      "/srv/glats/authelia/postgres.env"
    ];

    environment = {
      POSTGRES_USER = "authelia";
      POSTGRES_DB = "authelia";
    };

    extraOptions = [
      "--network=authelia"
      "--cpus=0.5"
      "--memory=512m"
      "--health-cmd=pg_isready -U authelia"
      "--health-interval=10s"
      "--health-timeout=5s"
      "--health-retries=5"
    ];
  };

  # Redis for Authelia sessions
  virtualisation.oci-containers.containers.authelia-redis = {
    image = "redis:7-alpine";
    autoStart = true;

    volumes = [
      "/srv/glats/authelia/redis:/data"
      "/srv/glats/authelia/redis/redis.conf:/etc/redis/redis.conf"
    ];

    cmd = [
      "redis-server"
      "/etc/redis/redis.conf"
    ];

    extraOptions = [
      "--network=authelia"
      "--cpus=0.25"
      "--memory=256m"
      "--health-cmd=redis-cli ping"
      "--health-interval=10s"
      "--health-timeout=5s"
      "--health-retries=5"
    ];
  };

  systemd.services.docker-autheliadb = {
    after = [ "docker-network-authelia.service" "authelia-secrets.service" ];
    requires = [ "docker-network-authelia.service" "authelia-secrets.service" ];
  };

  systemd.services.docker-authelia-redis = {
    after = [ "docker-network-authelia.service" "authelia-secrets.service" ];
    requires = [ "docker-network-authelia.service" "authelia-secrets.service" ];
  };

  # Authelia container using official Docker image
  virtualisation.oci-containers.containers.authelia = {
    image = "authelia/authelia:latest";
    autoStart = true;

    volumes = [
      "/srv/glats/authelia:/config"
    ];

    environmentFiles = [
      "/srv/glats/authelia/authelia.env"
    ];

    extraOptions = [
      "--network=authelia"
      "--cpus=0.5"
      "--memory=512m"
      "--health-cmd=wget --no-verbose --tries=1 --spider http://127.0.0.1:9091/api/health || exit 1"
      "--health-interval=30s"
      "--health-timeout=10s"
      "--health-retries=3"
    ];

    ports = [
      "127.0.0.1:9091:9091"
    ];
  };

  # Copy users.yml before starting Authelia (authelia.yml is generated by authelia-secrets)
  systemd.services.authelia-config = {
    description = "Copy Authelia users.yml file";
    after = [ "authelia-secrets.service" ];
    before = [ "docker-authelia.service" ];
    wantedBy = [ "docker-authelia.service" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = pkgs.writeShellScript "copy-authelia-users" ''
        cp ${usersYml} /srv/glats/authelia/users.yml
        chmod 600 /srv/glats/authelia/users.yml
      '';
      RemainAfterExit = true;
    };
  };

  systemd.services.docker-authelia = {
    after = [ "docker-network-authelia.service" "authelia-secrets.service" "authelia-config.service" ];
    requires = [ "docker-network-authelia.service" "authelia-secrets.service" "authelia-config.service" ];
  };

  # Create authelia service directory
  systemd.services.authelia-setup = {
    description = "Setup Authelia directories";
    wantedBy = [ "multi-user.target" ];
    before = [ "docker-network-authelia.service" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = pkgs.writeShellScript "authelia-dir-setup" ''
        mkdir -p /srv/glats/authelia
        chmod 700 /srv/glats/authelia
      '';
    };
  };

}
