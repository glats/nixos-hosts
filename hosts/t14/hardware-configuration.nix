{ lib, ... }:

{
  # Placeholder only.
  # Regenerate this file on the target machine with:
  # nixos-generate-config --root /mnt

  boot.initrd.availableKernelModules = lib.mkDefault [ ];
  boot.kernelModules = lib.mkDefault [ ];

  fileSystems."/" = lib.mkDefault {
    device = "/dev/disk/by-uuid/REPLACE-WITH-T14-ROOT-UUID";
    fsType = "btrfs";
  };

  fileSystems."/boot" = lib.mkDefault {
    device = "/dev/disk/by-uuid/REPLACE-WITH-T14-BOOT-UUID";
    fsType = "vfat";
  };

  swapDevices = lib.mkDefault [ ];
}
