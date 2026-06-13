# Hardware configuration — generado por `nixos-generate-config` desde
# el sistema en producción. NO editar a mano. Para regenerar:
#   sudo nixos-generate-config
#   sudo mv /etc/nixos/hardware-configuration.nix hosts/t14/hardware-configuration.nix
{ config, lib, pkgs, modulesPath, ... }:

{
  imports =
    [
      (modulesPath + "/installer/scan/not-detected.nix")
    ];

  boot.initrd.availableKernelModules = [ "nvme" "ehci_pci" "xhci_pci_renesas" "xhci_pci" "uas" "usb_storage" "sd_mod" "rtsx_pci_sdmmc" ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-amd" ];
  boot.extraModulePackages = [ ];

  fileSystems."/" =
    {
      device = "/dev/disk/by-uuid/d4506bf4-ce65-4d2e-8515-5da41a9ed2bb";
      fsType = "btrfs";
    };

  fileSystems."/home" =
    {
      device = "/dev/disk/by-uuid/d4506bf4-ce65-4d2e-8515-5da41a9ed2bb";
      fsType = "btrfs";
      options = [ "subvol=home" ];
    };

  fileSystems."/nix" =
    {
      device = "/dev/disk/by-uuid/d4506bf4-ce65-4d2e-8515-5da41a9ed2bb";
      fsType = "btrfs";
      options = [ "subvol=nix" ];
    };

  fileSystems."/boot" =
    {
      device = "/dev/disk/by-uuid/35BB-2D84";
      fsType = "vfat";
      options = [ "fmask=0077" "dmask=0077" ];
    };

  swapDevices =
    [{ device = "/dev/disk/by-uuid/2d3bf74b-ab94-473a-b684-6f995fdf7b69"; }];

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}
