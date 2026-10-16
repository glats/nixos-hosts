{ config, pkgs, ... }:

{
  virtualisation.oci-containers.containers.droppy = {
    image = "ghcr.io/droppyjs/droppy:v1.3.1";
    autoStart = true;
    ports = [ "9002:8989" ];
    volumes = [
      "/srv/glats/droppy/config:/config"
      "/run/media/stuff/droppy:/files"
      "/run/media/library/music:/files/music:ro"
    ];
    extraOptions = [ "--memory=768m" ];
  };

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
