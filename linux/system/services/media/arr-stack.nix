{
  config,
  pkgs,
  lib,
  ...
}:

{
  users.groups.media = { };

  users.users.glats.extraGroups = lib.mkAfter [ "media" ];

  users.users.radarr.extraGroups = [ "media" ];
  users.users.sonarr.extraGroups = [ "media" ];
  users.users.bazarr.extraGroups = [ "media" ];

  services.prowlarr = {
    enable = true;
    dataDir = "/srv/glats/prowlarr";
    openFirewall = false;
  };

  systemd.services.prowlarr = {
    after = [ "flaresolverr.service" ];
    requires = [ "flaresolverr.service" ];
  };

  services.radarr = {
    enable = true;
    dataDir = "/srv/glats/radarr";
    openFirewall = false;
  };

  services.sonarr = {
    enable = true;
    dataDir = "/srv/glats/sonarr";
    openFirewall = false;
  };

  services.bazarr = {
    enable = true;
    dataDir = "/srv/glats/bazarr";
    listenPort = 6767;
    openFirewall = false;
  };

  systemd.tmpfiles.settings."10-radarr"."/srv/glats/radarr".d = lib.mkForce {
    user = "radarr";
    group = "media";
    mode = "0775";
  };

  systemd.tmpfiles.settings."10-bazarr"."/srv/glats/bazarr".d = lib.mkForce {
    user = "bazarr";
    group = "media";
    mode = "0775";
  };

  systemd.tmpfiles.rules = [
    "d /srv/glats 0755 root root -"

    "d /srv/glats/prowlarr 0755 root root -"
    "d /srv/glats/sonarr 0775 sonarr media -"

    "d /srv/glats/downloads 0775 qbittorrent media -"
    "d /srv/glats/downloads/.incomplete 0775 qbittorrent media -"

    "d /run/media/library/video/movies 0775 glats media -"
    "d /run/media/library/video/series 0775 glats media -"
  ];

  systemd.services.arr-media-permissions = {
    description = "Fix permissions for ARR stack media directories";
    after = [ "run-media-library.mount" ];
    wantedBy = [ "multi-user.target" ];
    before = [
      "radarr.service"
      "sonarr.service"
      "bazarr.service"
      "qbittorrent.service"
      "prowlarr.service"
    ];

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
