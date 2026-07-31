{
  config,
  pkgs,
  lib,
  home,
  ...
}:

{
  imports = [
    ./hardware-configuration.nix
    ./secrets.nix
    ./conky-config.nix

    # Base system
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
    ../../linux/system/base/shutdown-debug.nix

    # Desktop
    ../../linux/system/desktop/fonts.nix
    ../../linux/system/desktop/i18n.nix
    ../../linux/system/desktop/kmscon.nix

    # Hardware
    ../../linux/system/hardware/nvidia-custom.nix
    ../../linux/system/hardware/keyring.nix
    ../../linux/system/hardware/asus-fan-control.nix
    ../../linux/system/hardware/rog-shutdown.nix # KEPT — under test, possible future use
    ../../linux/system/hardware/rog-poweroff-workaround.nix
    ../../linux/system/hardware/adb.nix

    # Networking
    ../../linux/system/networking/openssh.nix
    ../../linux/system/networking/firewall.nix
    ../../linux/system/networking/avahi.nix
    ../../linux/system/networking/wol.nix

    # Features
    ../../linux/system/features/boot.nix
    ../../linux/system/features/conky/options.nix

    # Services — shared
    ../../linux/system/services/xrdp.nix
    ../../linux/system/services/github-mcp-server.nix
    ../../linux/system/services/github-token-check.nix

    # Services — media
    ../../linux/system/services/media/arr-stack.nix
    ../../linux/system/services/media/jellyfin.nix
    ../../linux/system/services/media/qbittorrent.nix
    ../../linux/system/services/media/flaresolverr.nix

    # Services — web
    ../../linux/system/services/web/nginx.nix
    ../../linux/system/services/web/authelia.nix
    ../../linux/system/services/web/seerr.nix
    ../../linux/system/services/web/dozzle.nix
    ../../linux/system/services/web/fileshelter.nix
    ../../linux/system/services/web/code-server.nix
    ../../linux/system/services/web/wetty.nix
    ../../linux/system/services/web/cobalt.nix
    ../../linux/system/services/web/droppy.nix

    # Services — network
    ../../linux/system/services/network/wireguard.nix
    ../../linux/system/services/network/ddclient.nix
    ../../linux/system/services/network/samba.nix
    ../../linux/system/services/network/ftp.nix
    ../../linux/system/services/network/guacamole.nix
    ../../linux/system/services/network/gonic.nix
    ../../linux/system/services/network/ollama.nix

    # Virtualisation
    ../../linux/system/virtualisation/libvirt.nix
    ../../linux/system/virtualisation/docker.nix

    # Host-specific systemd timeout overrides
    ./systemd-timeouts.nix
  ];

  boot-settings = {
    enable = true;
    includeAcpiOsi = false;
    includePoweroffFix = false;
    # Verbose kernel/systemd logging to the console for shutdown-hang
    # post-mortem. Pairs with modules/base/shutdown-debug.nix which
    # snapshots the journal to /var/log/ at end of shutdown.
    includeDiagLogging = true;
  };

  # Enable the shutdown-debug-capture service. Without this the
  # imported module is a no-op.
  my.shutdownDebug.enable = true;

  hardware.rog.poweroffWorkaround.enable = true;
  hardware.rog.poweroffWorkaround.mode = "direct";
  services.asus-fan-control-custom.enable = false;

  # Blacklist non-essential ASUS WMI modules to prevent firmware
  # ACPI interactions that cause shutdown hangs. asus_wmi + hid_asus
  # (keyboard) remain loaded.
  boot.blacklistedKernelModules = [
    "asus_nb_wmi"
    "asus_armoury"
  ];

  # Desktop suite — rog uses MATE via XRDP
  my.desktop.suite = "mate";

  boot = {
    kernelPackages = pkgs.linuxPackages;
    extraModulePackages = with config.boot.kernelPackages; [ acpi_call ];
    kernelModules = [ "acpi_call" ];
  };

  zramSwap.enable = true;

  nixpkgs.config = {
    allowUnfree = true;
    permittedInsecurePackages = [ ];
    allowUnfreePackages = [ "joypixels" ];
    joypixels.acceptLicense = true;
  };

  networking = {
    hostName = "rog";
    networkmanager.enable = true;
  };

  services.wol-custom.interface = "enp3s0";

  fileSystems."/run/media/library" = {
    device = "/dev/disk/by-uuid/608cd7cf-3cb4-4589-8f36-c558fb4e32a3";
    fsType = "ext4";
    options = [ "defaults" ];
  };

  fileSystems."/run/media/stuff" = {
    device = "/dev/disk/by-uuid/ec889a15-ee5a-4b41-b3a0-60b16257026a";
    fsType = "xfs";
    options = [
      "rw"
      "relatime"
      "attr2"
      "inode64"
      "logbufs=8"
      "logbsize=32k"
      "noquota"
    ];
  };

  fileSystems."/run/media/archlinux" = {
    device = "/dev/disk/by-uuid/3188527d-b895-460a-b754-c396b876d8bf";
    fsType = "xfs";
    options = [
      "rw"
      "relatime"
      "attr2"
      "inode64"
      "logbufs=8"
      "logbsize=32k"
      "noquota"
    ];
  };

  system.stateVersion = "25.05";

  # Fix 1: Extend timeouts to prevent exit status 4 in nixos-rebuild switch
  # See: investigation of intermittent systemd-run switch-to-configuration failures
  # Use mkForce to override the oci-containers module defaults
  systemd.services.nginx.serviceConfig.TimeoutStartSec = lib.mkForce "300";
  systemd.services."acme-glats.org".serviceConfig.TimeoutStartSec = lib.mkForce "300";
  systemd.services."docker-droppy".serviceConfig.TimeoutStartSec = lib.mkForce "300";
  systemd.services."docker-guacamoledb".serviceConfig.TimeoutStartSec = lib.mkForce "300";
  systemd.services."docker-jellyfin".serviceConfig.TimeoutStartSec = lib.mkForce "300";
  systemd.services."docker-jellyseerr".serviceConfig.TimeoutStartSec = lib.mkForce "300";

  # Prevent restart loops that consume time during switch
  # Use mkForce because nginx already defines this value
  systemd.services.nginx.startLimitIntervalSec = lib.mkForce 0;
  systemd.services."docker-droppy".startLimitIntervalSec = lib.mkForce 0;
  systemd.services."docker-jellyfin".startLimitIntervalSec = lib.mkForce 0;
  systemd.services."docker-guacamoledb".startLimitIntervalSec = lib.mkForce 0;
  systemd.services."docker-jellyseerr".startLimitIntervalSec = lib.mkForce 0;

  environment.systemPackages = with pkgs; [
    asus-fan-control
    pipewire-module-xrdp
    intel-vaapi-driver
    libva-vdpau-driver
  ];

}
