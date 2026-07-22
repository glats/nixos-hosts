{ config, pkgs, lib, ... }:

{
  # ============================================================
  # Shared media group for arr services and user
  # Allows all services to read/write downloads and media
  # ============================================================
  users.groups.media = { };

  # Add user glats to media group
  users.users.glats.extraGroups = lib.mkAfter [ "media" ];

  # Add arr service users to media group
  # Note: Prowlarr uses DynamicUser=true in upstream module,
  # so we cannot add it to media group via static user definition.
  # Prowlarr doesn't need media access (indexer manager only).
  # Users/groups for radarr/sonarr/bazarr created by upstream modules.
  users.users.radarr.extraGroups = [ "media" ];
  users.users.sonarr.extraGroups = [ "media" ];
  users.users.bazarr.extraGroups = [ "media" ];

  # ============================================================
  # Prowlarr - Indexer manager for Torrent trackers and Usenet
  # Web UI: http://127.0.0.1:9696
  # ============================================================
  services.prowlarr = {
    enable = true;
    dataDir = "/srv/glats/prowlarr";
    openFirewall = false;
  };

  # Prowlarr depends on FlareSolverr for Cloudflare-bypassed trackers
  systemd.services.prowlarr = {
    after = [ "flaresolverr.service" ];
    requires = [ "flaresolverr.service" ];
  };

  # ============================================================
  # Radarr - Movie collection manager
  # Web UI: http://127.0.0.1:7878
  # ============================================================
  services.radarr = {
    enable = true;
    dataDir = "/srv/glats/radarr";
    openFirewall = false;
  };

  # ============================================================
  # Sonarr - TV series collection manager
  # Web UI: http://127.0.0.1:8989
  # ============================================================
  services.sonarr = {
    enable = true;
    dataDir = "/srv/glats/sonarr";
    openFirewall = false;
  };

  # ============================================================
  # Bazarr - Subtitle manager for Radarr/Sonarr
  # Web UI: http://127.0.0.1:6767
  # ============================================================
  services.bazarr = {
    enable = true;
    dataDir = "/srv/glats/bazarr";
    listenPort = 6767;
    openFirewall = false;
  };

  # ============================================================
  # Directory structure - Service config directories
  # ============================================================
  # Override upstream tmpfiles for radarr (upstream uses 0700 radarr:radarr)
  systemd.tmpfiles.settings."10-radarr"."/srv/glats/radarr".d = lib.mkForce {
    user = "radarr";
    group = "media";
    mode = "0775";
  };

  # Override upstream tmpfiles for bazarr (upstream uses 0700 bazarr:bazarr)
  systemd.tmpfiles.settings."10-bazarr"."/srv/glats/bazarr".d = lib.mkForce {
    user = "bazarr";
    group = "media";
    mode = "0775";
  };

  systemd.tmpfiles.rules = [
    # Parent directory for all service data
    "d /srv/glats 0755 root root -"

    # Service config directories (owned by service user, media group)
    # Prowlarr handled by upstream module (DynamicUser, bind-mount)
    # Radarr/bazarr overridden via systemd.tmpfiles.settings above
    "d /srv/glats/sonarr 0775 sonarr media -"

    # Download directories (shared, writable by media group)
    "d /srv/glats/downloads 0775 qbittorrent media -"
    "d /srv/glats/downloads/.incomplete 0775 qbittorrent media -"

    # Media directories (readable by media group)
    "d /run/media/library/video/movies 0775 glats media -"
    "d /run/media/library/video/series 0775 glats media -"
  ];

  # ============================================================
  # Persistent permissions setup for media directories
  # Ensures arr services can write to library after reboots
  # ============================================================
  systemd.services.arr-media-permissions = {
    description = "Fix permissions for ARR stack media directories";
    after = [ "run-media-library.mount" ];
    wantedBy = [ "multi-user.target" ];
    before = [ "radarr.service" "sonarr.service" "bazarr.service" "qbittorrent.service" "prowlarr.service" ];

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = pkgs.writeShellScript "arr-media-permissions" ''
        #!/bin/bash
        set -e

        # Ensure mount point is accessible (group media can traverse)
        if [ -d /run/media/library ]; then
          chgrp media /run/media/library || true
          chmod 775 /run/media/library || true
        fi

        if [ -d /run/media/library/video ]; then
          chgrp media /run/media/library/video || true
          chmod 775 /run/media/library/video || true
        fi

        # Fix movies directory - ACLs for group media (rwx)
        if [ -d /run/media/library/video/movies ]; then
          chown glats:media /run/media/library/video/movies || true
          chmod 775 /run/media/library/video/movies || true
          ${pkgs.acl}/bin/setfacl -m g:media:rwx /run/media/library/video/movies || true
          ${pkgs.acl}/bin/setfacl -d -m g:media:rwx /run/media/library/video/movies || true
        fi

        # Fix series directory - ACLs for group media (rwx)
        if [ -d /run/media/library/video/series ]; then
          chown glats:media /run/media/library/video/series || true
          chmod 775 /run/media/library/video/series || true
          ${pkgs.acl}/bin/setfacl -m g:media:rwx /run/media/library/video/series || true
          ${pkgs.acl}/bin/setfacl -d -m g:media:rwx /run/media/library/video/series || true
        fi

        # Re-assert downloads directory permissions (created by tmpfiles at boot)
        chown qbittorrent:media /srv/glats/downloads || true
        chown qbittorrent:media /srv/glats/downloads/.incomplete || true
        chmod 775 /srv/glats/downloads || true
        chmod 775 /srv/glats/downloads/.incomplete || true
      '';
    };
  };
}
