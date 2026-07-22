{ config, pkgs, lib, ... }:

{
  # ============================================================
  # qBittorrent - BitTorrent client with Web UI
  # Web UI: http://127.0.0.1:8080
  # Torrent port: 6881 (for incoming connections)
  # Configure via Web UI on first run
  # ============================================================
  services.qbittorrent = {
    enable = true;
    package = pkgs.qbittorrent-nox;

    # Ports
    webuiPort = 8080;
    torrentingPort = 6881;
    profileDir = "/srv/glats/qbittorrent";

    openFirewall = true;
  };

  # Add qbittorrent user to media group
  # User/group created by upstream NixOS module
  users.users.qbittorrent.extraGroups = [ "media" ];

  # Create directories with correct ownership before qbittorrent starts
  # Note: /srv/glats/downloads tmpfiles managed centrally in arr-stack.nix
  systemd.tmpfiles.rules = [
    "d /srv/glats/qbittorrent 0775 qbittorrent media -"
    "d /srv/glats/qbittorrent/qBittorrent 0775 qbittorrent media -"
    "d /srv/glats/qbittorrent/qBittorrent/config 0775 qbittorrent media -"
  ];
}
