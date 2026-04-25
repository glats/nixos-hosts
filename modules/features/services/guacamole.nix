{ config, pkgs, ... }:

let
  # Generate guacamole.properties from sops secret at runtime.
  # The file is placed in /srv/glats/guacamole/config/ and mounted as GUACAMOLE_HOME.
  # The container entrypoint uses this as a template, appending enable-environment-properties.
  # Password is read from the decrypted sops file, never stored in the Nix store.
  generateProperties = pkgs.writeShellScript "generate-guacamole-properties" ''
        PROPS_DIR="/srv/glats/guacamole/config"
        PROPS_FILE="$PROPS_DIR/guacamole.properties"
        SECRET_FILE="${config.sops.secrets."guacamole/env".path}"

        mkdir -p "$PROPS_DIR"

        # Source the sops secret file to get POSTGRESQL_PASSWORD
        . "$SECRET_FILE"

        cat > "$PROPS_FILE" <<PROPS
    # Guacamole properties - generated at runtime from sops secrets
    # PostgreSQL authentication (explicit, not via env vars)
    postgresql-hostname: guacamoledb
    postgresql-port: 5432
    postgresql-database: guacamole
    postgresql-username: guacamole
    postgresql-password: $POSTGRESQL_PASSWORD

    # Guacamole daemon
    guacd-hostname: guacamoled
    guacd-port: 4822
    PROPS

        chmod 644 "$PROPS_FILE"
  '';
in

{
  # Guacamole Stack - Remote Desktop
  # Data in /srv/glats/guacamole/
  # Properties file generated at runtime from sops secrets (see generateProperties)

  # Ensure guacamole docker network exists before containers start
  # Docker networks are created imperatively via systemd — idempotent.
  # Requires docker daemon to be up (after docker.service).
  systemd.services.docker-network-guacamole = {
    description = "Docker network for Guacamole";
    after = [ "docker.service" ];
    requires = [ "docker.service" ];
    before = [
      "docker-guacamoledb.service"
      "docker-guacamoled.service"
      "docker-guacamole.service"
    ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = pkgs.writeShellScript "create-guacamole-network" ''
        # Check if network exists, create if not
        if ! ${pkgs.docker}/bin/docker network ls --format '{{.Name}}' 2>/dev/null | grep -q "^guacamole$"; then
          echo "Creating guacamole docker network..."
          ${pkgs.docker}/bin/docker network create \
            --driver bridge \
            --subnet 10.89.0.0/24 \
            --gateway 10.89.0.1 \
            guacamole 2>/dev/null || true
        else
          echo "Guacamole network already exists"
        fi
      '';
    };
  };

  # 1. PostgreSQL Database
  virtualisation.oci-containers.containers.guacamoledb = {
    image = "postgres:17-alpine";
    autoStart = true;

    volumes = [
      "/srv/glats/guacamole/dbinit:/docker-entrypoint-initdb.d"
      "/srv/glats/guacamole/dbdata:/var/lib/postgresql/data"
    ];

    environment = {
      POSTGRES_USER = "guacamole";
      POSTGRES_DB = "guacamole";
      GUACAMOLE_DATABASE_USER = "guacamole";
      GUACAMOLE_DATABASE_NAME = "guacamole";
    };

    environmentFiles = [ config.sops.secrets."guacamole/env".path ];

    extraOptions = [
      "--network=guacamole"
      "--cpus=1.0"
      "--memory=1g"
      "--health-cmd=pg_isready -U guacamole"
      "--health-interval=10s"
      "--health-timeout=5s"
      "--health-retries=5"
    ];
  };

  # 2. Guacd - Guacamole Daemon
  virtualisation.oci-containers.containers.guacamoled = {
    image = "guacamole/guacd";
    autoStart = true;

    environment = {
      GUACD_LOG_LEVEL = "info";
    };

    extraOptions = [
      "--network=guacamole"
      "--memory=512m"
    ];
  };

  # 3. Guacamole Web Interface
  virtualisation.oci-containers.containers.guacamole = {
    image = "guacamole/guacamole";
    autoStart = true;

    ports = [
      "9003:8080"
    ];

    # Mount the generated guacamole.properties as GUACAMOLE_HOME template.
    # The entrypoint reads this file as a base and appends enable-environment-properties.
    # Explicit postgresql-* properties in the file take precedence over env vars.
    volumes = [
      "/srv/glats/guacamole/config:/etc/guacamole:ro"
    ];

    environment = {
      GUACAMOLE_HOME = "/etc/guacamole";
      LOG_LEVEL = "info";
      # Must be set so the entrypoint installs the PostgreSQL auth extension.
      # Actual connection properties come from the guacamole.properties file.
      POSTGRESQL_ENABLED = "true";
    };

    extraOptions = [
      "--network=guacamole"
      "--memory=512m"
    ];
  };

  # Ensure all guacamole containers wait for the network
  systemd.services.docker-guacamoledb = {
    after = [ "docker-network-guacamole.service" ];
    requires = [ "docker-network-guacamole.service" ];
  };

  systemd.services.docker-guacamoled = {
    after = [ "docker-network-guacamole.service" ];
    requires = [ "docker-network-guacamole.service" ];
  };

  # Generate guacamole.properties before starting the web container
  systemd.services.docker-guacamole = {
    after = [
      "docker-guacamoledb.service"
      "docker-guacamoled.service"
    ];
    requires = [
      "docker-guacamoledb.service"
      "docker-guacamoled.service"
    ];
    serviceConfig = {
      ExecStartPre = [
        "+${generateProperties}"
      ];
    };
  };
}
