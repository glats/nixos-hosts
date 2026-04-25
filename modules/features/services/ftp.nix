{ config, pkgs, ... }:

{
  # vsftpd - FTP Server
  services.vsftpd = {
    enable = true;

    # Allow local users
    localUsers = true;

    # Chroot for local users
    chrootlocalUser = true;

    # Allow writing in chroot
    allowWriteableChroot = true;

    # Root directory for local users
    localRoot = "/run/media/archlinux/home/glats/home-server/ftp";

    # Additional configuration
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

  # Open ports in firewall
  networking.firewall.allowedTCPPorts = [ 20 21 ];
  networking.firewall.allowedTCPPortRanges = [{ from = 47400; to = 47470; }];

  # Ensure directory exists
  systemd.tmpfiles.rules = [
    "d /run/media/archlinux/home/glats/home-server/ftp 0755 glats users -"
  ];
}
