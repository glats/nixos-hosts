# T14 — ThinkPad T14 con GNOME temporal.
# Endgame: Hyprland + Omarchy (ver t14-context.md Phase 1).
# Este host mantiene una importación mínima de módulos para sobrevivir
# el merge; el resto se activa progresivamente.
{ lib, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix

    # === BASE (mínimo viable) ===
    ../../modules/base/cachix.nix
    ../../modules/base/nix.nix
    ../../modules/base/polkit.nix
    ../../modules/base/sops.nix
    ../../modules/base/users.nix
    ../../modules/base/zsh.nix
    ../../modules/base/logind.nix
    ../../modules/base/packages.nix
    # NOTA: modules/base/home-manager.nix NO se importa — usamos nuestra
    # propia config de home-manager abajo con un set mínimo.

    # === DESKTOP (TEMPORAL — migraremos a Hyprland+Omarchy) ===
    ../../modules/desktop/gnome.nix
    ../../modules/desktop/i18n.nix
    ../../modules/desktop/fonts.nix
    ../../modules/desktop/kmscon.nix

    # === HARDWARE ===
    ../../modules/hardware/amd-laptop.nix

    # === NETWORKING (mínimo) ===
    ../../modules/networking/openssh.nix
    ../../modules/networking/avahi.nix

    # === HOST SECRETS (vacío por ahora) ===
    ./secrets.nix

    # === BOOT ===
    # Necesario: el sistema no bootea sin bootloader configurado.
    ../../modules/features/boot.nix
  ];

  networking = {
    hostName = "t14";
    networkmanager.enable = true;
    # Sin firewall en t14 (decisión del usuario: entorno de desarrollo,
    # máquina de un solo usuario en redes controladas).
    firewall.enable = false;
  };

  nixpkgs.config = {
    allowUnfree = true;
    # fonts.nix incluye joypixels; requiere aceptación explícita de licencia.
    allowUnfreePackages = [ "joypixels" ];
    joypixels.acceptLicense = true;
  };

  # Habilita el módulo de boot importado (systemd-boot, plymouth, kernel zen)
  boot-settings.enable = true;

  # Keymap específico de t14: layout latam (Chile). modules/desktop/i18n.nix
  # usa "es" por compatibilidad con rog/thinkcentre; acá forzamos latam.
  services.xserver.xkb = {
    layout = lib.mkForce "latam";
    variant = "";
  };
  console.keyMap = lib.mkForce "la-latin1";

  # SOPS en t14: usamos solo SSH key como age identity. modules/base/sops.nix
  # configura un keyFile separado (/var/lib/sops-nix/key.txt) que no
  # generamos en este host; lo anulamos explícitamente para que la
  # activation no falle.
  sops.age.keyFile = lib.mkForce "/dev/null";
  sops.age.generateKey = lib.mkForce false;

  # === HOME-MANAGER ===
  # Set mínimo para fase GNOME-temporal. No importamos
  # modules/base/home-manager.nix para evitar su lista full de imports.
  # El módulo NixOS de home-manager lo carga lib/mkHost.nix.
  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    users.glats = {
      imports = [ ./home/gnome-temp.nix ];
    };
  };

  system.stateVersion = "26.05";
}
