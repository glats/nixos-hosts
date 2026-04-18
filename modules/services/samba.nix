{ config, pkgs, ... }:

{
  # Samba server
  services.samba = {
    enable = true;
    openFirewall = true;

    # Global configuration using settings (attribute format)
    settings = {
      global = {
        workgroup = "WORKGROUP";
        "server string" = "Home Server Samba";
        "hosts allow" = "127.0.0.0/8 172.16.0.0/24";
        "map to guest" = "Bad User";
        "force user" = "glats";
        "force group" = "users";
        "create mask" = "0664";
        "directory mask" = "0775";
      };

      # Public share
      public = {
        path = "/run/media/stuff/samba";
        comment = "Public";
        browseable = "yes";
        "read only" = "no";
        "guest ok" = "yes";
      };
    };
  };

  # Network discovery for Windows (wsdd2)
  services.samba-wsdd = {
    enable = true;
    openFirewall = true;
  };

  # Ensure directory exists and has correct permissions
  systemd.tmpfiles.rules = [
    "d /run/media/stuff/samba 0775 glats glats -"
  ];
}
