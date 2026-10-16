{ config, pkgs, ... }:

{
  services.gonic = {
    enable = true;

    settings = {
      listen-addr = "127.0.0.1:4747";

      music-path = "/run/media/library/music";
      data-path = "/srv/glats/gonic/data";
      cache-path = "/var/cache/gonic";
      playlists-path = "/srv/glats/gonic/playlists";
      podcast-path = "/srv/glats/gonic/podcasts";
    };
  };

  systemd.services.gonic.serviceConfig = {
    ReadOnlyPaths = [ "/run/media/library/music" ];
  };

  systemd.tmpfiles.rules = [
    "d /var/cache/gonic 0755 gonic gonic -"
  ];
}
