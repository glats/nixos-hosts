{ config, pkgs, ... }:

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
      "--user=0:0"
    ];
  };
}
