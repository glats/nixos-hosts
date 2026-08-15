{ config, pkgs, ... }:

{
  # Droppy - Self-hosted file dropzone
  # Config: /srv/glats/droppy/config
  # Data: /run/media/stuff/droppy
  virtualisation.oci-containers.containers.droppy = {
    image = "ghcr.io/droppyjs/droppy:v1.3.1";
    autoStart = true;
    ports = [ "9002:8989" ];
    volumes = [
      "/srv/glats/droppy/config:/config"
      "/run/media/stuff/droppy:/files"
    ];
    extraOptions = [ "--memory=768m" ];
  };

  # Fix permissions for droppy files. The container runs as root (the
  # ghcr.io/droppyjs image only works as root — its docker-start.sh runs
  # `su droppy` but node lives under /root/.volta), so uploads land root:root
  # with variable mode. Timer-driven so uploads self-heal and nginx can read
  # them. `a+rX` applies to the DATA dir only — never the config dir,
  # which holds db.json (accounts + password hashes).
  systemd.services.droppy-permissions = {
    description = "Fix permissions for Droppy files";
    after = [
      "docker-droppy.service"
      "run-media-stuff.mount"
    ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = pkgs.writeShellScript "droppy-fix-perms" ''
        #!/bin/bash
        # Config dir: keep owner-only access (contains db.json)
        if [ -d /srv/glats/droppy ]; then
          chown -R glats:users /srv/glats/droppy || true
          chmod -R u+rwx /srv/glats/droppy || true
        fi

        # Data dir: must be readable by nginx (served at /uploads and /files)
        if [ -d /run/media/stuff/droppy ]; then
          chown -R glats:users /run/media/stuff/droppy || true
          chmod -R u+rwX,go+rX /run/media/stuff/droppy || true
        fi
      '';
    };
  };

  systemd.timers.droppy-permissions = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "2min";
      OnUnitActiveSec = "15min";
      Persistent = true;
    };
  };
}
