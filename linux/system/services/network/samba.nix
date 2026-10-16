{ config, pkgs, ... }:

{
  services.samba = {
    enable = true;
    openFirewall = true;

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

      public = {
        path = "/run/media/stuff/samba";
        comment = "Public";
        browseable = "yes";
        "read only" = "no";
        "guest ok" = "yes";
      };

      roms = {
        path = "/run/media/library/roms";
        comment = "ROMs";
        browseable = "yes";
        "read only" = "yes";
        "guest ok" = "yes";
      };
    };
  };

  services.samba-wsdd = {
    enable = true;
    openFirewall = true;
  };

  services.avahi.extraServiceFiles = {
    smb = ''
      <?xml version="1.0" standalone="no"?>
      <!DOCTYPE service-group SYSTEM "avahi-service.dtd">
      <service-group>
        <name replace-wildcards="yes">SMB on %h</name>
        <service>
          <type>_smb._tcp</type>
          <port>445</port>
        </service>
      </service-group>
    '';
  };

  systemd.tmpfiles.rules = [
    "d /run/media/stuff/samba 0775 glats glats -"
  ];
}
