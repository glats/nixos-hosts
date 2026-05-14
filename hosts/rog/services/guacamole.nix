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

  # Set up the guacadmin user password and rotate the PostgreSQL role password.
  # Runs on every boot to ensure passwords are always current after sops rotation.
  # Idempotent via ON CONFLICT DO UPDATE, so running on every boot is safe.
  systemd.services.guacamole-admin-setup = {
    description = "Guacamole admin user and database password setup";
    after = [ "docker-guacamoledb.service" ];
    requires = [ "docker-guacamoledb.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      # Do NOT set RemainAfterExit = true here.
      # The service must re-run on every boot so that a sops password rotation
      # takes effect immediately (no manual restart needed).
      User = "root";
      ExecStart = pkgs.writeScript "guacamole-admin-setup" ''
          #!${pkgs.python3}/bin/python3
          import sys
          import os
          import hashlib
          import secrets
          import subprocess
          import time

          docker = "${pkgs.docker}/bin/docker"

          # Retry loop: PostgreSQL may not be ready on first boot.
          # Try up to 10 times with 2-second intervals.
          max_attempts = 10
          for attempt in range(1, max_attempts + 1):
              check_cmd = [docker, "exec", "guacamoledb",
                           "pg_isready", "-U", "guacamole"]
              result = subprocess.run(check_cmd, capture_output=True, text=True, timeout=10)
              if result.returncode == 0:
                  break
              if attempt < max_attempts:
                  sys.stdout.write("PostgreSQL not ready (attempt " + str(attempt) + "/" + str(max_attempts) + "), retrying in 2s...\n")
                  time.sleep(2)
              else:
                  sys.stderr.write("PostgreSQL not ready after " + str(max_attempts) + " attempts\n")
                  sys.exit(1)

          # Phase 1: Parse env file to get GUACAMOLE_DATABASE_PASSWORD
          env_path = "${config.sops.secrets."guacamole/env".path}"
          env_vars = {}
          try:
              with open(env_path, 'r') as f:
                  for line in f:
                      if '=' in line:
                          k, v = line.strip().split('=', 1)
                          env_vars[k] = v
          except Exception as e:
              sys.stderr.write("Error reading env file: " + str(e) + "\n")
              sys.exit(1)

          db_password = env_vars.get('GUACAMOLE_DATABASE_PASSWORD')
          if not db_password:
              sys.stderr.write("Error: GUACAMOLE_DATABASE_PASSWORD not found or empty in env file\n")
              sys.exit(1)

          # Phase 2: ALTER ROLE to update the PostgreSQL role password
          sq = chr(39)
          escaped_password = db_password.replace(sq, sq + sq)
          alter_sql = "ALTER ROLE guacamole WITH PASSWORD " + sq + escaped_password + sq + ";"
          try:
              alter_result = subprocess.run(
                  [docker, "exec", "-i", "guacamoledb",
                   "psql", "-U", "guacamole", "-d", "guacamole"],
                  input=alter_sql, text=True, capture_output=True, timeout=30
              )
              if alter_result.returncode != 0:
                  sys.stderr.write("ALTER ROLE failed: " + alter_result.stderr + "\n")
                  sys.exit(1)
              sys.stdout.write("Successfully updated guacamole role password\n")
          except Exception as e:
              sys.stderr.write("Error executing ALTER ROLE: " + str(e) + "\n")
              sys.exit(1)

          # Phase 3: Verify connectivity with the new password
          try:
              verify_result = subprocess.run(
                  [docker, "exec", "-i", "guacamoledb",
                   "psql", "-U", "guacamole", "-d", "guacamole",
                   "-c", "SELECT 1;"],
                  capture_output=True, text=True, timeout=10,
                  env={**os.environ, "PGPASSWORD": db_password}
              )
              if verify_result.returncode != 0:
                  sys.stderr.write("Password verification failed: " + verify_result.stderr + "\n")
                  sys.exit(1)
              sys.stdout.write("Password verification passed\n")
          except Exception as e:
              sys.stderr.write("Error verifying password: " + str(e) + "\n")
              sys.exit(1)

          # Phase 4: Set up guacadmin user password (SHA-256 hash)
          secret_path = "${config.sops.secrets."guacamole/admin_password".path}"
          try:
              with open(secret_path, 'r') as f:
                  password = f.read().strip()
          except Exception as e:
              sys.stderr.write("Error reading password secret: " + str(e) + "\n")
              sys.exit(1)

          if not password:
              sys.stderr.write("Error: admin password is empty\n")
              sys.exit(1)

          # Guacamole hashes: SHA-256(password_string + salt_hex_uppercase)
          # See: SHA256PasswordEncryptionService.java in guacamole-auth-jdbc-base
          salt = secrets.token_bytes(32)
          salt_hex_upper = salt.hex().upper()
          hash_input = (password + salt_hex_upper).encode('utf-8')
          password_hash = hashlib.sha256(hash_input).digest()
          hash_hex = password_hash.hex()
          salt_hex = salt.hex()

          upsert_sql = (
              "INSERT INTO guacamole_entity (name, type) VALUES ('guacadmin', 'USER') "
              "ON CONFLICT (name, type) DO UPDATE SET name = 'guacadmin'; "
              "INSERT INTO guacamole_user (entity_id, password_hash, password_salt, password_date, disabled) "
              "SELECT entity_id, decode('" + hash_hex + "', 'hex'), decode('" + salt_hex + "', 'hex'), NOW(), FALSE "
              "FROM guacamole_entity WHERE name = 'guacadmin' AND type = 'USER' "
              "ON CONFLICT (entity_id) DO UPDATE SET "
              "password_hash = EXCLUDED.password_hash, "
              "password_salt = EXCLUDED.password_salt, "
              "password_date = NOW();"
          )

          verify_sql = (
              "SELECT length(password_hash), length(password_salt) FROM guacamole_user u "
              "JOIN guacamole_entity e ON u.entity_id = e.entity_id "
              "WHERE e.name = 'guacadmin' AND e.type = 'USER';"
          )

          cmd = [docker, "exec", "-i", "guacamoledb",
                 "psql", "-U", "guacamole", "-d", "guacamole", "-c", upsert_sql]
          try:
              result = subprocess.run(cmd, capture_output=True, text=True, timeout=30)
              if result.returncode != 0:
                  sys.stderr.write("UPSERT SQL execution failed: " + result.stderr + "\n")
                  sys.stderr.write("stdout: " + result.stdout + "\n")
                  sys.exit(1)
              sys.stdout.write("Successfully configured guacadmin password\n")
          except Exception as e:
              sys.stderr.write("Error executing docker exec: " + str(e) + "\n")
              sys.exit(1)

          # Verify the stored bytes have the expected length (32 bytes each for hash and salt).
          verify_cmd = [docker, "exec", "-i", "guacamoledb",
                        "psql", "-U", "guacamole", "-d", "guacamole", "-t", "-c", verify_sql]
          try:
              verify_result = subprocess.run(verify_cmd, capture_output=True, text=True, timeout=30)
              if verify_result.returncode != 0:
                  sys.stderr.write("Verification SQL failed: " + verify_result.stderr + "\n")
                  sys.exit(1)
              output = verify_result.stdout.strip()
              parts = output.split("|")
              if len(parts) != 2:
                  sys.stderr.write("Unexpected verification output format: " + output + "\n")
                  sys.exit(1)
              hash_len = int(parts[0].strip())
              salt_len = int(parts[1].strip())
              if hash_len != 32 or salt_len != 32:
                  sys.stderr.write("Verification failed: expected hash_len = 32 salt_len=32, got hash_len=" + str(hash_len) + " salt_len=" + str(salt_len) + "\n")
                  sys.exit(1)
              sys.stdout.write("Verification passed: hash_len=" + str(hash_len) + ", salt_len=" + str(salt_len) + "\n")
          except Exception as e:
              sys.stderr.write("Error executing verification: " + str(e) + "\n")
              sys.exit(1)
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
  # Also waits for guacamole-admin-setup to ensure the admin user and db password are ready.
  systemd.services.docker-guacamole = {
    after = [
      "docker-guacamoledb.service"
      "docker-guacamoled.service"
      "guacamole-admin-setup.service"
    ];
    requires = [
      "docker-guacamoledb.service"
      "docker-guacamoled.service"
      "guacamole-admin-setup.service"
    ];
    serviceConfig = {
      ExecStartPre = [
        "+${generateProperties}"
      ];
    };
  };
}

