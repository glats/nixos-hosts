{
  config,
  lib,
  pkgs,
  modulesPath,
  ...
}:

{
  imports = [
    (modulesPath + "/installer/cd-dvd/installation-cd-minimal-new-kernel.nix")
  ];

  # ISO does not need a real hardware scan
  # Omit hardware-configuration.nix — uses generic kernel modules
  boot.loader.grub.enable = lib.mkForce false;
  boot.loader.systemd-boot.enable = lib.mkForce true;

  # Live user for testing
  users.users.nixos = {
    isNormalUser = true;
    extraGroups = [
      "wheel"
      "networkmanager"
    ];
    password = "nixos";
  };

  services.displayManager.autoLogin = {
    enable = true;
    user = "nixos";
  };

  # Tools available in ISO for install + debug
  environment.systemPackages = with pkgs; [
    opencode
    git
    vim
    wget
    curl
    parted
    gptfdisk
    dosfstools
    xfsprogs
    util-linux
  ];

  # Install guide + script baked into ISO
  environment.etc."nixos/t14-install.sh".source = ./install.sh;
  environment.etc."nixos/INSTALL.md".source   = ./INSTALL.md;
}
