# T14 — ThinkPad T14 AMD Gen 4 running Omarchy (Hyprland-based).
#
# Migrated from temporary GNOME to permanent Omarchy desktop. The omarchy
# NixOS module is wired in via flake.nix extraModules (omarchy-nix +
# nixos-hardware T14 profile). This host file provides the per-host overrides:
#   - omarchy config block (username, identity, theme, monitors, browser,
#     terminal, firewall disabled)
#   - XKB layout forced to "latam" (Chile) since i18n.nix defaults to "es"
#   - btrfs swap, fonts, kmscon, and amd-laptop settings inherited from base
#   - home-manager wired to ./home/omarchy.nix (replaces ./home/gnome.nix)
{
  config,
  lib,
  pkgs,
  ...
}:

{
  imports = [
    ./hardware-configuration.nix

    # === BASE (minimal viable) ===
    ../../modules/base/cachix.nix
    ../../modules/base/nix.nix
    ../../modules/base/polkit.nix
    ../../modules/base/sops.nix
    ../../modules/base/users.nix
    ../../modules/base/zsh.nix
    ../../modules/base/packages.nix
    # NOTE: modules/base/home-manager.nix is NOT imported — we use our
    # own home-manager config below with a targeted set.

    # === DESKTOP ===
    # Omarchy provides greetd + Hyprland + PipeWire + NetworkManager (iwd
    # backend) + Bluetooth + printing + gvfs. The previous GNOME module
    # (modules/desktop/gnome.nix) and avahi module
    # (modules/networking/avahi.nix) are no longer imported because
    # omarchy's system.nix supersedes them.
    ../../modules/desktop/i18n.nix
    ../../modules/desktop/fonts.nix
    ../../modules/desktop/kmscon.nix

    # === HARDWARE ===
    ../../modules/hardware/amd-laptop.nix

    # === NETWORKING ===
    ../../modules/networking/openssh.nix

    # === HOST SECRETS ===
    ./secrets.nix

    # === BOOT ===
    # Required: the system will not boot without bootloader configured.
    ../../modules/features/boot.nix

    # === MCP REQUIREMENTS ===
    ../../modules/features/services/github-mcp-server.nix
    ../../modules/virtualisation/docker.nix
  ];

  networking = {
    hostName = "t14";
    networkmanager.enable = true;
    # Defense-in-depth: keep host firewall off. Omarchy's firewall is
    # explicitly disabled below via omarchy.firewall.enable = false, but
    # this line ensures the NixOS-level firewall also stays off.
    firewall.enable = false;
  };

  nixpkgs.config = {
    allowUnfree = true;
    # fonts.nix includes joypixels; requires explicit license acceptance.
    allowUnfreePackages = [ "joypixels" ];
    joypixels.acceptLicense = true;
  };

  # Enable the imported boot module (systemd-boot, plymouth, zen kernel)
  boot-settings.enable = true;

  # t14-specific keymap: latam (Chile) layout. modules/desktop/i18n.nix
  # uses "es" for compatibility with rog/thinkcentre; we force latam here.
  services.xserver.xkb = {
    layout = lib.mkForce "latam";
    variant = "";
  };
  console.keyMap = lib.mkForce "la-latin1";

  # === OMARCHY CONFIG BLOCK ===
  # Omarchy reads these options from the imported NixOS module to decide
  # which themes/monitors/identities to deploy. The full_name and
  # email_address are placeholders until sops-backed user identity is
  # wired in (tracked in proposal "Open Questions").
  omarchy = {
    username = "glats";
    full_name = "Glats";
    email_address = "glats@local";

    # tokyo-night is the upstream base; the custom "glats" theme is
    # deployed via xdg.configFile in hosts/t14/home/omarchy.nix and
    # overrides the runtime theme files without changing this enum.
    theme = "tokyo-night";

    # Built-in 14" 1920x1200 panel; external monitors are managed by
    # monitor-hotplug-handler.sh (see hosts/t14/home/hypr/autostart.nix).
    monitors = [ "DP-2,preferred,auto,1" ];

    # Laptop panel is 1x scale (1920x1200 native).
    scale = 1;

    browser = "brave";
    terminal = "ghostty";

    # No firewall — development machine on controlled networks.
    # REQ-003: omarchy.firewall.enable = false is the canonical way to
    # opt out of omarchy's mkIf-guarded firewall module.
    firewall.enable = false;
  };

  # === HOME-MANAGER ===
  # Omarchy + t14 Hyprland overlays imported via ./home/omarchy.nix.
  # The NixOS home-manager module is loaded by lib/mkHost.nix.
  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    extraSpecialArgs = {
      hostName = config.networking.hostName;
    };
    users.glats = {
      imports = [ ./home/omarchy.nix ];
    };
  };

  system.stateVersion = "26.05";
}
