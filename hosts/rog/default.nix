{ config
, pkgs
, lib
, inputs
, ...
}:

{
  imports = [
    ./hardware-configuration.nix

    # === BASE (individual, NOT profile chain) ===
    ../../modules/base/cachix.nix
    ../../modules/base/options.nix
    ../../modules/base/dconf.nix
    # NOT: ../../modules/base/home-manager.nix (HM defined inline below)
    ../../modules/base/logind.nix
    ../../modules/base/nh.nix
    ../../modules/base/nix.nix
    ../../modules/base/packages.nix
    ../../modules/base/polkit.nix
    ../../modules/base/shutdown-fix.nix
    ../../modules/base/sops.nix
    ../../modules/base/users.nix
    ../../modules/base/zsh.nix

    # === DESKTOP ===
    ../../modules/desktop/fonts.nix
    ../../modules/desktop/i18n.nix
    ../../modules/desktop/kmscon.nix
    ../../modules/hardware/keyring.nix

    # === NETWORKING ===
    ../../modules/networking/avahi.nix
    ../../modules/networking/firewall.nix
    ../../modules/networking/openssh.nix

    # === BOOT ===
    ../../modules/features/boot.nix

    # === SERVER SERVICES ===
    ../../modules/features/services/xrdp.nix
    ../../modules/features/services/github-mcp-server.nix
    ../../modules/features/services/github-token-check.nix
    ../../modules/networking/wol.nix
    ../../modules/virtualisation/docker.nix

    # Rog secrets
    ./secrets.nix

    # Rog conky config
    ./conky-config.nix

    # Conky module (options from features/conky)
    ../../modules/features/conky

    # Hardware (rog-specific)
    ../../modules/hardware/nvidia.nix
    ../../modules/hardware/rog-shutdown.nix
    ../../modules/hardware/rog-poweroff-workaround.nix
    ../../modules/hardware/asus-fan-control.nix

    # Shutdown diagnostics — captures journal/dmesg/ps/mounts to
    # /var/log/shutdown-debug/{boot-id}/ at end of shutdown. Rog-only
    # because the hang is observed on this host; thinkcentre is clean.
    ../../modules/base/shutdown-debug.nix

    # Services (rog-specific)
    ./services/arr-stack.nix
    ./services/authelia.nix
    ./services/cobalt.nix
    ./services/code-server.nix
    ./services/ddclient.nix
    ./services/dozzle.nix
    ./services/droppy.nix
    ./services/fileshelter.nix
    ./services/flaresolverr.nix
    ./services/ftp.nix
    ./services/gonic.nix
    ./services/guacamole.nix
    ./services/jellyfin.nix
    ./services/nginx.nix
    ./services/ollama.nix
    ./services/qbittorrent.nix
    ./services/samba.nix
    ./services/seerr.nix
    ./services/wetty.nix
    ./services/wireguard.nix

    # Virtualisation (rog-specific)
    ../../modules/virtualisation/libvirt.nix
  ];

  # Home Manager (inline, NOT via profile chain)
  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "backup";
    extraSpecialArgs = {
      inherit inputs;
      hostName = config.networking.hostName;
      conkyConfig = config.conky-config;
      username = "glats";
    };
    users.glats.imports = import ./home/modules.nix { inherit inputs; };
  };

  # === OMARCHY DESKTOP (Hyprland on Intel iGPU) ===
  # greetd is masked in PR2 -- enabled in PR3
  omarchy = {
    username = "glats";
    full_name = "Glats";
    email_address = "glats@local";
    theme = "glats";
    scale = 1;
    browser = "brave";
    terminal = "ghostty";
    monitors = [ "eDP-1,preferred,auto,1" ];

    # Keep rog's own firewall (omarchy's is disabled)
    firewall.enable = false;

    # Do NOT activate omarchy's NVIDIA module -- rog uses nvidia.nix
    nvidia.enable = lib.mkForce false;

    # Disable lid-switch handling (HandleLidSwitch=ignore already set)
    hyprland.lidSwitch.enable = false;

    # Greeter defined but service masked -- unmasked in PR3
    greeter = {
      type = "regreet";
    };
  };

  # Mask greetd from auto-starting until PR3 (Hyprland per-host configs)
  systemd.services.greetd.wantedBy = lib.mkForce [ ];

  boot-settings = {
    enable = true;
    includeAcpiOsi = false;
    includePoweroffFix = true;
    # Verbose kernel/systemd logging to the console for shutdown-hang
    # post-mortem. Pairs with modules/base/shutdown-debug.nix which
    # snapshots the journal to /var/log/ at end of shutdown.
    includeDiagLogging = true;
  };

  # Enable the shutdown-debug-capture service. Without this the
  # imported module is a no-op.
  my.shutdownDebug.enable = true;

  hardware.rog.poweroffWorkaround.enable = true;
  services.asus-fan-control-custom.enable = false;

  # Blacklist non-essential ASUS WMI modules to prevent firmware
  # ACPI interactions that cause shutdown hangs. asus_wmi + hid_asus
  # (keyboard) remain loaded.
  boot.blacklistedKernelModules = [ "asus_nb_wmi" "asus_armoury" ];

  # Desktop suite — rog uses MATE via XRDP
  my.desktop.suite = "mate";

  boot = {
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

}
