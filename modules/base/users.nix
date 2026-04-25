{ config, lib, pkgs, ... }:

{
  programs = {
    dconf.enable = true;

    gnupg.agent = {
      enable = true;
      enableSSHSupport = true;
    };

    nix-ld.enable = true;
    nix-ld.libraries = with pkgs; [ ];
  };

  users.users.glats = {
    isNormalUser = true;
    home = "/home/glats";
    description = "Glats user";
    extraGroups = [ "input" "networkmanager" "sound" "tty" "wheel" "audio" "video" "docker" "libvirtd" ];
    shell = pkgs.zsh;
    hashedPasswordFile = config.sops.secrets."glats_hashed_password".path;
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMmEZnnbGhOicYhWnRFRQ7f8DEDHElwqQ5mHp9Zr+Xwi glats@nixos-rog"
    ];
  };

  users.groups.netdev = { };

  security.sudo.wheelNeedsPassword = false;
}
