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

  # Tools available in ISO for debugging
  environment.systemPackages = with pkgs; [
    opencode
    git
    vim
    wget
    curl
  ];
}
