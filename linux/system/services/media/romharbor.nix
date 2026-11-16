{ lib, ... }:

{
  services.romharbor = {
    enable = true;
    address = "127.0.0.1:8082";
    user = "glats";
    group = "users";
    libraryPath = "/run/media/library/roms";
    cachePath = "/var/lib/romharbor/cache";
    databasePath = "/var/lib/romharbor/app.db";
    sources = [ "archive.org" ];
  };

  systemd.services.romharbor = {
    after = [
      "network-online.target"
      "run-media-library.mount"
    ];
    wants = [ "network-online.target" ];
    requires = [ "run-media-library.mount" ];
    serviceConfig = {
      UMask = lib.mkForce "0022";
      MemoryMax = "1G";
      ProtectKernelTunables = true;
      ProtectKernelModules = true;
      ProtectControlGroups = true;
      RestrictAddressFamilies = [
        "AF_INET"
        "AF_INET6"
        "AF_UNIX"
      ];
    };
  };

  systemd.tmpfiles.rules = [
    "d /run/media/library/roms 0775 glats media -"
  ];
}
