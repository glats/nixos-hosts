{ config
, pkgs
, lib
, home
, ...
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
    ../../linux/system/hardware/rog-poweroff.nix
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

    # Services — media
    ../../linux/system/services/media/arr-stack.nix
    ../../linux/system/services/media/jellyfin.nix
    ../../linux/system/services/media/qbittorrent.nix
    ../../linux/system/services/media/flaresolverr.nix
    # ../../linux/system/services/media/romarr.nix   # TODO: file missing after refactor
    ../../linux/system/services/media/romm.nix
    # ../../linux/system/services/media/grabarr.nix  # TODO: file missing after refactor

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
    ../../linux/system/services/network/sing-box-link.nix
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
    # Verbose kernel/systemd logging to the console for shutdown-hang
    # post-mortem. Pairs with linux/system/base/shutdown-debug.nix which
    # snapshots the journal to /var/log/ at end of shutdown.
    includeDiagLogging = true;
  };

  # Enable the shutdown-debug-capture service. Without this the
  # imported module is a no-op.
  my.shutdownDebug.enable = true;

  # Also copy EFI pstore records (dmesg-efi-*) into the capture dir —
  # with the diagnostics kernel params below, a failed shutdown leaves
  # its kmsg dump there and rog keeps it across the reboot.
  my.shutdownDebug.efiPstore = true;

  # Diagnostics gate + S5 write hook (openspec change
  # rog-shutdown-s5-diagnose-and-fix): netconsole probe to the thinkcentre
  # receiver (defaults already match the deployed receiver: enp3s0 ->
  # 172.16.0.11:6666, MAC 6c:4b:90:2d:97:42, rog source port 6665),
  # printk.always_kmsg_dump=1 + EFI pstore kept active.
  #
  # s5Write = Gate 2: EXECUTED 2026-09-10 00:34 — CONCLUSIVE NEGATIVE. The
  # corrected write fired (breadcrumbs) and the firmware froze at the S5
  # transition itself; no kernel/AML-side change can fix a non-AML hang.
  # Disabled again so the write can never pre-empt the EFI handler.
  hardware.rog.s5-recovery.diagnostics.enable = true;
  hardware.rog.s5-recovery.s5Write.enable = false;

  # efiFallback = Gate 3 (supervised trial): DMI-scoped EFI ResetSystem
  # power-off handler (priority 225 replaces the freezing ACPI S5 final
  # entry; acpi_power_off_prepare still runs first per T14 RFC v3 lesson).
  hardware.rog.s5-recovery.efiFallback.enable = true;

  # Blacklist non-essential ASUS WMI modules: their AML calls
  # (_SB.ATKD.WMNB) fail loudly on this firmware and add ACPI
  # interaction noise at the S5 boundary. asus_wmi + hid_asus
  # (keyboard) remain loaded.
  boot.blacklistedKernelModules = [
    "asus_nb_wmi"
    "asus_armoury"
  ];

  # Desktop suite — rog uses MATE via XRDP
  my.desktop.suite = "mate";

  boot = {
    kernelPackages = pkgs.linuxPackages;
    # acpi_call is required by the manually-run `sudo asus-fan-control
    # set-temps ...` CLI. The periodic service stays disabled
    # (disabled during shutdown-hang isolation, 2026-07); manual use only.
    extraModulePackages = with config.boot.kernelPackages; [ acpi_call ];
    kernelModules = [ "acpi_call" ];
    # NOTE: previous shutdown-hack layers (rog-shutdown service, port-I/O
    # poweroff hook, acpi=noirq) were removed 2026-09-07 —
    # see openspec change rog-shutdown-s5-diagnose-and-fix for the
    # current approach. Only the working baseline remains: shutdown-debug
    # capture + WMI blacklist + watchdog config in shutdown-fix.nix.
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

  # Private-link loopback VLESS+WS server (module provides the option;
  # import alone does not enable it). See
  # linux/system/services/network/sing-box-link.nix.
  services.sing-box-link.enable = true;

  # Fix 1: Extend timeouts to prevent exit status 4 in nixos-rebuild switch
  # See: investigation of intermittent systemd-run switch-to-configuration failures
  # Use mkForce to override the oci-containers module defaults
  systemd.services.nginx.serviceConfig.TimeoutStartSec = lib.mkForce "300";
  systemd.services."acme-glats.org".serviceConfig.TimeoutStartSec = lib.mkForce "300";
  systemd.services."docker-droppy".serviceConfig.TimeoutStartSec = lib.mkForce "300";
  systemd.services."docker-guacamoledb".serviceConfig.TimeoutStartSec = lib.mkForce "300";
  systemd.services."docker-jellyfin".serviceConfig.TimeoutStartSec = lib.mkForce "300";
  systemd.services."docker-jellyseerr".serviceConfig.TimeoutStartSec = lib.mkForce "300";
  systemd.services."docker-romm-db".serviceConfig.TimeoutStartSec = lib.mkForce "300";

  # Prevent restart loops that consume time during switch
  # Use mkForce because nginx already defines this value
  systemd.services.nginx.startLimitIntervalSec = lib.mkForce 0;
  systemd.services."docker-droppy".startLimitIntervalSec = lib.mkForce 0;
  systemd.services."docker-jellyfin".startLimitIntervalSec = lib.mkForce 0;
  systemd.services."docker-guacamoledb".startLimitIntervalSec = lib.mkForce 0;
  systemd.services."docker-jellyseerr".startLimitIntervalSec = lib.mkForce 0;

  environment.systemPackages = with pkgs; [
    microsoft-edge
    asus-fan-control
    pipewire-module-xrdp
    intel-vaapi-driver
    libva-vdpau-driver
    qrencode # bin/device-link QR output when run via sudo from the tree
  ];
}
