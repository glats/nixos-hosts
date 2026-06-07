# T14 — ThinkPad T14 with temporary GNOME.
# Endgame: Hyprland + Omarchy (see t14-context.md Phase 1).
# This host keeps a minimal module import set to survive the merge;
# the rest is activated progressively.
{ lib, pkgs, ... }:

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
    # own home-manager config below with a minimal set.

    # === DESKTOP (TEMPORARY — will migrate to Hyprland+Omarchy) ===
    ../../modules/desktop/gnome.nix
    ../../modules/desktop/i18n.nix
    ../../modules/desktop/fonts.nix
    ../../modules/desktop/kmscon.nix

    # === HARDWARE ===
    ../../modules/hardware/amd-laptop.nix

    # === NETWORKING (minimal) ===
    ../../modules/networking/openssh.nix
    ../../modules/networking/avahi.nix

    # === HOST SECRETS (empty for now) ===
    ./secrets.nix

    # === BOOT ===
    # Required: the system will not boot without bootloader configured.
    ../../modules/features/boot.nix
  ];

  networking = {
    hostName = "t14";
    networkmanager.enable = true;
    # No firewall on t14 (user decision: development environment,
    # single-user machine on controlled networks).
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

  # === HOME-MANAGER ===
  # Minimal set for the GNOME-temporary phase. We do not import
  # modules/base/home-manager.nix to avoid its full import list.
  # The NixOS home-manager module is loaded by lib/mkHost.nix.
  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    users.glats = {
      imports = [ ./home/gnome-temp.nix ];
    };
  };

  system.stateVersion = "26.05";
}
