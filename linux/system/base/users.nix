{ config
, lib
, pkgs
, ...
}:

{
  programs = {
    dconf.enable = true;

    gnupg.agent = {
      enable = true;
      enableSSHSupport = true;
      pinentryPackage = pkgs.pinentry-curses;
    };

    nix-ld.enable = true;
    nix-ld.libraries = with pkgs; [ ];
  };

  users.users.glats = {
    isNormalUser = true;
    home = "/home/glats";
    description = "Glats user";
    extraGroups = [
      "input"
      "networkmanager"
      "sound"
      "tty"
      "wheel"
      "audio"
      "video"
      "docker"
      "keys"
      "libvirtd"
    ];
    shell = pkgs.zsh;
    hashedPasswordFile = lib.mkIf
      (
        config ? sops && config.sops.secrets ? "glats_hashed_password"
      )
      config.sops.secrets."glats_hashed_password".path;
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMmEZnnbGhOicYhWnRFRQ7f8DEDHElwqQ5mHp9Zr+Xwi glats@nixos-rog"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKtoFLEVCeMwSVSCEdiUQgauZoKzU/aYZG8PBMN7CHQu glats@mac-t14"
    ];
  };

  users.groups.netdev = { };

  security.sudo.wheelNeedsPassword = false;

  environment.variables = {
    EDITOR = "nvim";
    VISUAL = "nvim";
  };
}
