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

  # Fix permissions for droppy files after container starts
  # Container runs as root, so files get created as root:root
  # This ensures glats can access config and files
  systemd.services.droppy-permissions = {
    description = "Fix permissions for Droppy files";
    after = [ "docker-droppy.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = pkgs.writeShellScript "droppy-fix-perms" ''
        #!/bin/bash
        # Fix config directory ownership
        chown -R glats:users /srv/glats/droppy 2>/dev/null || true
        chmod -R u+rwx /srv/glats/droppy 2>/dev/null || true
        
        # Fix data directory ownership (existing files)
        chown -R glats:users /run/media/stuff/droppy 2>/dev/null || true
        chmod -R u+rwx /run/media/stuff/droppy 2>/dev/null || true
      '';
    };
  };
}
