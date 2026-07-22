{ config, pkgs, lib, ... }:

{
  virtualisation.oci-containers.containers.jellyfin = {
    image = "jellyfin/jellyfin:10.11.3";
    autoStart = true;

    volumes = [
      "/srv/glats/jellyfin/config:/config"
      "/srv/glats/jellyfin/cache:/cache"
      "/run/media/library/video:/media:ro"
    ];

    # Intel iGPU devices for QSV/VAAPI transcoding
    devices = [
      "/dev/dri/card1:/dev/dri/card1"
      "/dev/dri/renderD128:/dev/dri/renderD128"
    ];

    environment = {
      MALLOC_ARENA_MAX = "2";
      MALLOC_TRIM_THRESHOLD_ = "0";
      DOTNET_gcServer = "1";
      DOTNET_GCConserveMemory = "9";
      DOTNET_GCHeapHardLimitPercent = "0x5a";
      DOTNET_GCHighMemPercent = "0x30";
    };

    extraOptions = [
      "--network=host"
      "--group-add=${toString config.ids.gids.render}"
    ];
  };

  # Ensure config/cache directories exist with correct permissions
  systemd.tmpfiles.rules = [
    "d /srv/glats/jellyfin 0755 root root -"
    "d /srv/glats/jellyfin/config 0755 root root -"
    "d /srv/glats/jellyfin/cache 0755 root root -"
  ];

  # Order after media permissions service so ACLs on media dirs are set
  systemd.services."docker-jellyfin".after = [ "arr-media-permissions.service" ];
}
