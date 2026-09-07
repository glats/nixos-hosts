{ config
, pkgs
, lib
, ...
}:

{
  imports = [
    ./hardware-configuration.nix
    ./secrets.nix
    ./conky-config.nix

    # Base system (all 14)
    ../../linux/system/base/cachix.nix
    ../../linux/system/base/nix.nix
    ../../linux/system/base/users.nix
    ../../linux/system/base/zsh.nix
    ../../linux/system/base/sops.nix
    ../../linux/system/base/polkit.nix
    ../../linux/system/base/logind.nix
    ../../linux/system/base/nh.nix
    ../../linux/system/base/dconf.nix
    ../../linux/system/base/options.nix
    ../../linux/system/base/packages.nix
    ../../linux/system/base/home-manager.nix
    ../../linux/system/base/shutdown-fix.nix

    # Desktop (all 3)
    ../../linux/system/desktop/fonts.nix
    ../../linux/system/desktop/i18n.nix
    ../../linux/system/desktop/kmscon.nix

    # Hardware (keyring only)
    ../../linux/system/hardware/keyring.nix
    ../../linux/system/hardware/adb.nix

    # Networking (all 4)
    ../../linux/system/networking/openssh.nix
    ../../linux/system/networking/firewall.nix
    ../../linux/system/networking/avahi.nix
    ../../linux/system/networking/wol.nix

    # Features
    ../../linux/system/features/boot.nix
    ../../linux/system/features/conky/options.nix

    # Services
    ../../linux/system/services/xrdp.nix
    ../../linux/system/services/maquilinux-mounts.nix

    # Virtualisation
    ../../linux/system/virtualisation/docker.nix
  ];

  boot-settings = {
    enable = true;
  };

  boot.kernelPackages = pkgs.linuxPackages;

  # Desktop suite — thinkcentre uses MATE via XRDP
  my.desktop.suite = "mate";

  zramSwap.enable = true;

  nixpkgs.config = {
    allowUnfree = true;
    allowUnfreePackages = [ "joypixels" ];
    joypixels.acceptLicense = true;
  };

  networking = {
    hostName = "thinkcentre";
    networkmanager.enable = true;

    # Never let NM auto-create a default wired connection for enp0s31f6:
    # the declarative enp0s31f6-static profile (below) is the only profile
    # this NIC may have. This makes the one-time runtime cleanup
    # (nmcli con delete "Wired connection 1") permanent — if the stale
    # auto profile ever reappears, it cannot be recreated for this device.
    networkmanager.settings.main.no-auto-default = "enp0s31f6";

    # Netconsole receiver address (Slice 1 of rog-shutdown-s5-diagnose-and-fix):
    # pin the wired NIC statically so the netconsole target never moves.
    # Checkpoint A (live, 2026-09-07): enp0s31f6, single NM profile, gateway
    # and DNS 172.16.0.1, search domain "lan"; decision: fully static
    # ipv4.method=manual, no DHCP dependency.
    #
    # Option verified against pinned nixpkgs 26.05
    # (nixos/modules/services/networking/networkmanager.nix): there is no
    # networking.networkmanager.connectionConfigurations there — the
    # declarative mechanism is networking.networkmanager.ensureProfiles
    # .profiles, freeform INI atoms, so keyfile list settings
    # (addresses/dns/dns-search) are comma-separated strings.
    #
    # The runtime-created DHCP profile "Wired connection 1" still exists in
    # /etc/NetworkManager/system-connections; autoconnect-priority makes this
    # profile win for autoconnect. NixOS cannot delete runtime NM profiles,
    # so at deploy also run: nmcli con delete "Wired connection 1".
    networkmanager.ensureProfiles.profiles.enp0s31f6-static = {
      connection = {
        id = "enp0s31f6-static";
        type = "ethernet";
        interface-name = "enp0s31f6";
        autoconnect = true;
        autoconnect-priority = 100;
      };
      ipv4 = {
        method = "manual";
        addresses = "172.16.0.11/24";
        gateway = "172.16.0.1";
        dns = "172.16.0.1";
        dns-search = "lan";
      };
    };
  };

  # Netconsole UDP receiver: durably appends kernel lines (RFC3339 receive
  # timestamp prefix) to /var/log/netconsole/ and ACKs rog's nonce probes
  # (contract in pkgs/nixos-scripts/internal/netconsole). UDP 6666 inbound
  # and the ACK return to rog's :6665 need no firewall rule — the NixOS
  # firewall is disabled on thinkcentre via linux/system/networking/firewall.nix.
  systemd.services.netconsole-log = {
    description = "Netconsole UDP kernel log receiver";
    wantedBy = [ "multi-user.target" ];
    wants = [ "network-online.target" ];
    after = [ "network-online.target" ];
    serviceConfig = {
      ExecStart = "${pkgs.nixos-scripts}/bin/netconsole-log";
      DynamicUser = true;
      LogsDirectory = "netconsole";
      ReadWritePaths = [ "/var/log/netconsole" ];
      Restart = "always";
      RestartSec = "2s";
      NoNewPrivileges = true;
      ProtectSystem = "strict";
      ProtectHome = true;
    };
  };

  # Receiver log retention: weekly rotation, 8 weeks kept, compressed.
  services.logrotate.settings.netconsole = {
    files = [ "/var/log/netconsole/*.log" ];
    frequency = "weekly";
    rotate = 8;
    compress = true;
  };

  services.wol-custom.interface = "enp0s31f6";

  system.stateVersion = "25.05";

  environment.systemPackages = with pkgs; [
    microsoft-edge
    nixos-scripts
    pipewire-module-xrdp
    intel-vaapi-driver
    libva-vdpau-driver
  ];

}
