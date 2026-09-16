{
  config,
  lib,
  pkgs,
  ...
}:

let
  mesh = import ../../../shared/ssh/lan-mesh.nix { inherit lib; };
in

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
      "adbusers"
    ];
    shell = pkgs.zsh;
    hashedPasswordFile = lib.mkIf (
      config ? sops && config.sops.secrets ? "glats_hashed_password"
    ) config.sops.secrets."glats_hashed_password".path;
    openssh.authorizedKeys.keys = mesh.peerKeys config.networking.hostName;
  };

  users.groups.netdev = { };

  # ADB (used by XRDP hosts only — group exists unconditionally so extraGroups
  # doesn't fail on t14 where the udev rules aren't loaded)
  users.groups.adbusers = { };

  security.sudo.wheelNeedsPassword = false;

  environment.variables = {
    EDITOR = "nvim";
    VISUAL = "nvim";
  };
}
