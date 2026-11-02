{ config, pkgs, ... }:

{
  services.vsftpd = {
    enable = true;

    localUsers = true;

    chrootlocalUser = true;

    allowWriteableChroot = true;

    localRoot = "/run/media/stuff/ftp";

    extraConfig = ''
      # Passive ports (as in Docker)
      pasv_enable=YES
      pasv_min_port=47400
      pasv_max_port=47470
      pasv_address=172.16.0.5

      # Security
      ssl_enable=NO
      allow_anon_ssl=NO
      force_local_data_ssl=NO
      force_local_logins_ssl=NO

      # Logging
      xferlog_enable=YES
      log_ftp_protocol=YES

      # Limits
      max_clients=200
      max_per_ip=10
    '';
  };

  networking.firewall.allowedTCPPorts = [
    20
    21
  ];
  networking.firewall.allowedTCPPortRanges = [
    {
      from = 47400;
      to = 47470;
    }
  ];

  systemd.tmpfiles.rules = [
    "d /run/media/stuff/ftp 0755 glats users -"
  ];
}
