# TEMPORAL: GNOME como desktop mientras migramos a Hyprland+Omarchy.
# Ver: t14-context.md Phase 1 — activar Hyprland + Omarchy.
# Este módulo debe borrarse (junto con su import en hosts/t14/default.nix)
# cuando lleguemos a Phase 1.
{ config, lib, pkgs, ... }:

{
  services.xserver.enable = true;

  services.displayManager.gdm.enable = true;
  services.desktopManager.gnome.enable = true;

  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  programs.firefox.enable = true;

  environment.systemPackages = with pkgs; [
    neovim
    tmux
    opencode
  ];
}
