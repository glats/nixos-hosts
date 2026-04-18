{ config, pkgs, ... }:

{
  # ============================================================
  # Jellyseerr - Request management for Jellyfin
  # Web UI: http://127.0.0.1:5055
  # Integrates with Jellyfin for authentication
  # Using OCI container (native module not available in current nixpkgs)
  # ============================================================
  virtualisation.oci-containers.containers.jellyseerr = {
    image = "fallenbagel/jellyseerr:latest";
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
  systemd.tmpfiles.rules = [
    "d /srv/glats/jellyseerr 0755 root root -"
    "d /srv/glats/jellyseerr/config 0755 root root -"
  ];

  # Ensure directory exists before podman tries to mount it
  systemd.services."podman-jellyseerr".preStart = ''
    mkdir -p /srv/glats/jellyseerr/config
    chmod 755 /srv/glats/jellyseerr /srv/glats/jellyseerr/config
  '';
}
