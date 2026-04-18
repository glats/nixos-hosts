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
  # Must set isSystemUser and group when extending system users
  users.users.prowlarr = {
    isSystemUser = true;
    group = "prowlarr";
    extraGroups = [ "media" ];
  };
  users.groups.prowlarr = { };

  users.users.radarr = {
    isSystemUser = true;
    group = "radarr";
    extraGroups = [ "media" ];
  };
  users.groups.radarr = { };

  users.users.sonarr = {
    isSystemUser = true;
    group = "sonarr";
    extraGroups = [ "media" ];
  };
  users.groups.sonarr = { };

  users.users.bazarr = {
    isSystemUser = true;
    group = "bazarr";
    extraGroups = [ "media" ];
  };
  users.groups.bazarr = { };

  # ============================================================
  # Prowlarr - Indexer manager for Torrent trackers and Usenet
  # Web UI: http://127.0.0.1:9696
  # ============================================================
  services.prowlarr = {
    enable = true;
    dataDir = "/srv/glats/prowlarr";
    openFirewall = false;
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
  systemd.tmpfiles.rules = [
    # Service config directories (owned by service user, media group)
    "d /srv/glats/prowlarr 0775 prowlarr media -"
    "d /srv/glats/radarr 0775 radarr media -"
    "d /srv/glats/sonarr 0775 sonarr media -"
    "d /srv/glats/bazarr 0775 bazarr media -"

    # Download directories (shared, writable by media group)
    "d /srv/glats/downloads 0775 qbittorrent media -"
    "d /srv/glats/downloads/.incomplete 0775 qbittorrent media -"

    # Final media directories (writable by media group for Jellyfin)
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
    before = [ "radarr.service" "sonarr.service" "bazarr.service" "qbittorrent.service" ];

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = pkgs.writeShellScript "arr-media-permissions" ''
        #!/bin/bash
        set -e
        
        # Ensure mount point is accessible (group media can traverse)
        if [ -d /run/media/library ]; then
          chgrp media /run/media/library 2>/dev/null || true
          chmod 775 /run/media/library 2>/dev/null || true
        fi
        
        if [ -d /run/media/library/video ]; then
          chgrp media /run/media/library/video 2>/dev/null || true
          chmod 775 /run/media/library/video 2>/dev/null || true
        fi
        
        # Fix movies directory - ACLs for group media (rwx)
        if [ -d /run/media/library/video/movies ]; then
          chown glats:media /run/media/library/video/movies 2>/dev/null || true
          chmod 775 /run/media/library/video/movies 2>/dev/null || true
          ${pkgs.acl}/bin/setfacl -m g:media:rwx /run/media/library/video/movies 2>/dev/null || true
          ${pkgs.acl}/bin/setfacl -d -m g:media:rwx /run/media/library/video/movies 2>/dev/null || true
        fi
        
        # Fix series directory - ACLs for group media (rwx)
        if [ -d /run/media/library/video/series ]; then
          chown glats:media /run/media/library/video/series 2>/dev/null || true
          chmod 775 /run/media/library/video/series 2>/dev/null || true
          ${pkgs.acl}/bin/setfacl -m g:media:rwx /run/media/library/video/series 2>/dev/null || true
          ${pkgs.acl}/bin/setfacl -d -m g:media:rwx /run/media/library/video/series 2>/dev/null || true
        fi
        
        # Ensure downloads directory exists with correct permissions
        mkdir -p /srv/glats/downloads/.incomplete
        chown -R qbittorrent:media /srv/glats/downloads
        chmod 775 /srv/glats/downloads
        chmod 775 /srv/glats/downloads/.incomplete
      '';
    };
  };
}
