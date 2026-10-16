{
  config,
  pkgs,
  lib,
  ...
}:

{
  services.qbittorrent = {
    enable = true;
    package = pkgs.qbittorrent-nox;

    webuiPort = 8080;
    torrentingPort = 6881;
    profileDir = "/srv/glats/qbittorrent";

    openFirewall = true;
  };

  users.users.qbittorrent.extraGroups = [ "media" ];

  systemd.tmpfiles.rules = [
    "d /srv/glats/qbittorrent 0775 qbittorrent media -"
    "d /srv/glats/qbittorrent/qBittorrent 0775 qbittorrent media -"
    "d /srv/glats/qbittorrent/qBittorrent/config 0775 qbittorrent media -"
  ];
}
