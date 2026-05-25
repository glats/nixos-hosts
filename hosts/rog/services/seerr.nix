{ config, pkgs, ... }:

{
  # ============================================================
  # Jellyseerr - Request management for Jellyfin
  # Web UI: http://127.0.0.1:5055
  # Integrates with Jellyfin for authentication
  # Using OCI container (native module not available in current nixpkgs)
  # ============================================================
  virtualisation.oci-containers.containers.jellyseerr = {
    image = "fallenbagel/jellyseerr:2.5.0";
    autoStart = true;

    # Use host network so container can access localhost services
    extraOptions = [ "--network=host" ];

    volumes = [
      "/srv/glats/jellyseerr/config:/app/config"
    ];

    environment = {
      LOG_LEVEL = "info";
    };
  };

  # Create config directory via tmpfiles (for boot) AND preStart (for switch)
  # Container runs as UID 1000 (node user), so config dir must be writable
  systemd.tmpfiles.rules = [
    "d /srv/glats/jellyseerr 0755 root root -"
    "d /srv/glats/jellyseerr/config 0755 1000 1000 -"
  ];

  # Ensure directory exists before docker tries to mount it
  systemd.services."docker-jellyseerr".preStart = ''
    mkdir -p /srv/glats/jellyseerr/config
    chmod 755 /srv/glats/jellyseerr /srv/glats/jellyseerr/config
  '';
}
