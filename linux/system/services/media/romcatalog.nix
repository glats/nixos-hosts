{
  config,
  pkgs,
  lib,
  ...
}:

let
  port = 8082;
  libraryRoot = "/run/media/library/roms";
  cacheDir = "/var/lib/romcatalog";
in
{
  systemd.services.romcatalog = {
    description = "ROM catalog web service";
    wantedBy = [ "multi-user.target" ];
    after = [
      "network-online.target"
      "run-media-library.mount"
    ];
    wants = [ "network-online.target" ];
    requires = [ "run-media-library.mount" ];
    serviceConfig = {
      Type = "simple";
      User = "glats";
      Group = "users";
      ExecStart = lib.escapeShellArgs [
        "${pkgs.nixos-scripts}/bin/romcatalog"
        "--listen"
        "127.0.0.1:${toString port}"
        "--library"
        libraryRoot
        "--cache"
        cacheDir
        "--sources"
        "archive.org"
      ];
      Restart = "on-failure";
      RestartSec = "5";
      StateDirectory = "romcatalog";
      StateDirectoryMode = "0750";
      ReadWritePaths = [ libraryRoot ];
      NoNewPrivileges = true;
      PrivateTmp = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      ProtectKernelTunables = true;
      ProtectKernelModules = true;
      ProtectControlGroups = true;
      RestrictAddressFamilies = [
        "AF_INET"
        "AF_INET6"
        "AF_UNIX"
      ];
      MemoryMax = "1G";
      UMask = "0022";
    };
  };

  systemd.tmpfiles.rules = [
    "d ${libraryRoot} 0775 glats media -"
  ];
}
